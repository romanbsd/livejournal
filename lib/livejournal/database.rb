#!/usr/bin/ruby
#--
# ljrb -- LiveJournal Ruby module
# Copyright (c) 2005 Evan Martin <martine@danga.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#++
#
# This module interacts with the sqlite export from LogJam.

require 'sqlite3'

module LiveJournal
  # A SQLite database dump.
  class DatabaseError < RuntimeError; end
  class Database
    EXPECTED_DATABASE_VERSION = "1"
    SCHEMA = %q{
      CREATE TABLE meta (
        key STRING PRIMARY KEY,
        value STRING 
      );
      CREATE TABLE entry (
        itemid INTEGER PRIMARY KEY,
        anum INTEGER,
        subject STRING,
        event STRING,
        moodid INTEGER, mood STRING, music STRING, taglist STRING, 
        pickeyword STRING, preformatted INTEGER, backdated INTEGER, 
        comments INTEGER, year INTEGER, month INTEGER, day INTEGER, 
        timestamp INTEGER, security INTEGER
      );
      CREATE INDEX dateindex ON entry (year, month, day);
      CREATE INDEX timeindex ON entry (timestamp);
      CREATE TABLE comment (
        commentid INTEGER PRIMARY KEY,
        posterid INTEGER,
        itemid INTEGER,
        parentid INTEGER,
        state STRING,  -- screened/deleted/active
        subject STRING,
        body STRING,
        timestamp INTEGER  -- unix timestamp
      );
      CREATE INDEX commententry ON comment (itemid);
      CREATE TABLE users (
        userid INTEGER PRIMARY KEY,
        username STRING
      );
      CREATE TABLE commentprop (
        commentid INTEGER,  -- not primary key 'cause non-unique
        key STRING,
        value STRING
      );
      }.gsub(/^      /, '')

    def self.optional_to_i(x)
      return nil if x.nil?
      return x.to_i
    end

    attr_reader :db
    def initialize(filename, create=false)
      exists = FileTest::exists? filename if create
      @db = SQLite3::Database.new(filename)

      # We'd like to use type translation, but it unfortunately fails on MAX()
      # queries.
      # @db.type_translation = true

      if exists
        version = self.version
        unless version == EXPECTED_DATABASE_VERSION
          raise DatabaseError, "Database version mismatch -- db has #{version.inspect}, expected #{EXPECTED_DATABASE_VERSION.inspect}"
        end
      end

      #trace!
      if create and not exists
        run_schema!
        self.version = EXPECTED_DATABASE_VERSION
      end
    end

    def transaction
      @db.transaction { yield }
    end

    def close
      @db.close
    end

    def self.db_value(name, sym)
      class_eval %{def #{sym}; get_meta(#{name.inspect}); end}
      class_eval %{def #{sym}=(v); set_meta(#{name.inspect}, v); end}
    end

    db_value 'username', :username
    db_value 'lastsync', :lastsync
    db_value 'version', :version

    def run_schema!
      transaction do
        @db.execute_batch(SCHEMA)
      end
    end
    
    # Turn tracing on.
    def trace!
      @db.trace() do |data, sql|
        puts "SQL> #{sql.inspect}"
      end
    end

    # Fetch a specific itemid.
    def get_entry(itemid)
      query_entry("select * from entry where itemid=?", itemid)
    end

    # Given SQL that selects an entry, return that entry.
    def query_entry(sql, *sqlargs)
      row = @db.get_first_row(sql, *sqlargs)
      return Entry.new.load_from_database_row(row)
    end

    # Given SQL that selects some entries, yield each entry.
    def query_entries(sql, *sqlargs)
      @db.execute(sql, *sqlargs) do |row|
        yield Entry.new.load_from_database_row(row)
      end
    end

    # Yield most recent limit entries.
    def each_entry(limit=nil, &block)
      sql = 'SELECT * FROM entry ORDER BY itemid DESC'
      sql += " LIMIT #{limit}" if limit
      query_entries sql, &block
    end

    # Return the total number of entries.
    def total_entry_count
      @db.get_first_value('SELECT COUNT(*) FROM entry').to_i
    end

    def store_entry entry
      sql = 'INSERT OR REPLACE INTO entry VALUES (' + ("?, " * 16) + '?)'
      @db.execute(sql, *entry.to_database_row)
    end

    def last_comment_meta
      Database::optional_to_i(
          @db.get_first_value('SELECT MAX(commentid) FROM comment'))
    end
    def last_comment_full
      Database::optional_to_i(
          @db.get_first_value('SELECT MAX(commentid) FROM comment ' +
                              'WHERE body IS NOT NULL'))
    end

    def _store_comments(comments, meta_only=true)
      transaction do
        sql = "INSERT OR REPLACE INTO comment "
        if meta_only
          sql += "(commentid, posterid, state) VALUES (?, ?, ?)"
        else
          sql += "VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        end
        @db.prepare(sql) do |stmt|
          comments.each do |id, comment|
            if meta_only
              stmt.execute(comment.commentid, comment.posterid,
                           LiveJournal::Comment::state_to_string(comment.state))
            else
              stmt.execute(*comment.to_database_row)
            end
          end
        end
      end
    end

    def store_comments_meta(comments)
      _store_comments(comments, true)
    end
    def store_comments_full(comments)
      _store_comments(comments, false)
    end

    def store_usermap(usermap)
      transaction do
        sql = "INSERT OR REPLACE INTO users VALUES (?, ?)"
        @db.prepare(sql) do |stmt|
          usermap.each do |id, user|
            stmt.execute(id, user)
          end
        end
      end
    end

    def get_meta key
      return @db.get_first_value('SELECT value FROM meta WHERE key=?', key)
    end
    def set_meta key, value
      db.transaction do
        @db.execute('INSERT OR REPLACE INTO meta VALUES (?, ?)', key, value)
      end
    end
  end

  class Entry
    # Parse an entry from a row from the database.
    def load_from_database_row row
      @itemid, @anum = row[0].to_i, row[1].to_i
      @subject, @event = row[2], row[3]
      @moodid, @mood = row[4].nil? ? nil : row[4].to_i, row[5]
      @music, @taglist, @pickeyword = row[6], row[7], row[8]
      @taglist = if @taglist then @taglist.split(/, /) else [] end
      @preformatted, @backdated = !row[9].nil?, !row[10].nil?
      @comments = case Database::optional_to_i(row[11])
        when nil; :normal
        when 1; :none
        when 2; :noemail
        else raise DatabaseError, "Bad comments value: #{row[11].inspect}"
      end

      @time = Time.at(row[15].to_i).utc

      case Database::optional_to_i(row[16])
      when nil
        @security = :public
      when 0
        @security = :private
      when 1
        @security = :friends
      else
        @security = :custom
        @allowmask = row[16]
      end

      self
    end
    def to_database_row
      comments = case @comments
        when :normal; nil
        when :none; 1
        when :noemail; 2
      end
      security = case @security
        when :public; nil
        when :private; 0
        when :friends; 1
        when :custom; @allowmask
      end
      [@itemid, @anum, @subject, @event,
       @moodid, @mood, @music, @taglist.join(', '), @pickeyword,
       @preformatted ? 1 : nil, @backdated ? 1 : nil, comments,
       @time.year, @time.mon, @time.day, @time.to_i, security]
    end
  end
  class Comment
    def load_from_database_row row
      @commentid, @posterid = row[0].to_i, row[1].to_i
      @itemid, @parentid = row[2].to_i, row[3].to_i
      @state = Comment::state_from_string row[4]
      @subject, @body = row[5], row[6]
      @time = Time.at(row[7]).utc
      self
    end
    def to_database_row
      state = Comment::state_to_string @state
      [@commentid, @posterid, @itemid, @parentid,
       state, @subject, @body, @time.to_i]
    end
  end
end

# vim: ts=2 sw=2 et :
