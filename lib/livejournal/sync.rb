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

# A full sync involves both the LiveJournal flat protocol, for entries:
require 'livejournal/request'
# As well as a custom XML format via REST, for comments:
# http://www.livejournal.com/developer/exporting.bml
require 'open-uri'
require 'livejournal/comments-xml'

require 'livejournal/entry'
require 'livejournal/comment'

module LiveJournal
  module Request
    class SyncItems < Req
      attr_reader :syncitems, :fetched, :total
      def initialize(user, syncitems=nil, lastsync=nil)
        super(user, 'syncitems')
        @syncitems = syncitems || {}
        @request['lastsync'] = lastsync if lastsync
      end

      def run
        super
        lasttime = nil
        @fetched = 0
        @total = @result['sync_total'].to_i
        each_in_array('sync') do |item|
          item, time = item['item'], item['time']
          next if @syncitems.has_key? item
          @fetched += 1
          lasttime = time if lasttime.nil? or time > lasttime
          @syncitems[item] = time
        end
        lasttime
      end

      def self.subset_items(syncitems, want_type='L')
        items = {}
        syncitems.each do |item, time|
          next unless item =~ /^(.)-(\d+)$/
          type, id = $1, $2.to_i
          items[id] = time if type == want_type
        end
        items
      end
    end

    # This is only used for generating sessions used for syncing comments.
    # It is used by ljrb internally.
    class SessionGenerate < Req
      def initialize(user)
        super(user, 'sessiongenerate')
      end
      # Returns the LJ session.
      def run
        super
        @result['ljsession']
      end
    end
  end

  # Journal export.  A full export involves syncing both entries and comments.
  # See <tt>samples/export</tt> for a full example.
  module Sync

    # To run a sync, create a Sync::Entries object, then call
    # Entries#run_syncitems to fetch the sync metadata, then call
    # Entries#run_sync to get the actual entries.
    class Entries
      # To resume from a previous sync, pass in its lastsync value.
      attr_reader :lastsync

      def initialize(user, lastsync=nil)
        @user = user
        @logitems = {}
        @lastsync = lastsync
      end
      def run_syncitems  # :yields: cur, total
        cur = 0
        total = nil
        items = {}
        lastsync = @lastsync
        while total.nil? or cur < total
          req = Request::SyncItems.new(@user, items, lastsync)
          lastsync = req.run
          cur += req.fetched
          total = req.total unless total
          yield cur, total if block_given?
        end
        @logitems = Request::SyncItems::subset_items(items, 'L')
        return (not @logitems.empty?)
      end

      def run_sync  # :yields: entries_hash, lastsync, remaining_count
        return if @logitems.empty?

        lastsync = @lastsync
        while @logitems.size > 0
          req = Request::GetEvents.new(@user, :lastsync => lastsync)
          entries = req.run
          # pop off all items that we now have entries for
          entries.each do |itemid, entry|
            time = @logitems.delete itemid
            lastsync = time if lastsync.nil? or time > lastsync
          end
          yield entries, lastsync, @logitems.size
        end
      end
    end
    
    class Comments
      def initialize(user)
        @user = user
        @session = nil
        @maxid = nil
      end

      def run_GET(mode, start)
        unless @session
          req = Request::SessionGenerate.new(@user)
          @session = req.run
        end

        path = "/export_comments.bml?get=comment_#{mode}&startid=#{start}"
        # authas:  hooray for features discovered by reading source!
        path += "&authas=#{@user.usejournal}" if @user.usejournal

        data = nil
        open(@user.server.url + path,
             'Cookie' => "ljsession=#{@session}") do |f|
          # XXX stream this data to the XML parser.
          data = f.read
        end
        return data
      end
      private :run_GET

      def run_metadata(start=0)  # :yields: cur, total, comments_hash
        while @maxid.nil? or start < @maxid
          data = run_GET('meta', start)
          parsed = LiveJournal::Sync::CommentsXML::Parser.new(data)
          @maxid ||= parsed.maxid
          break if parsed.comments.empty?
          cur = parsed.comments.keys.max
          yield cur, @maxid, parsed
          start = cur + 1
        end
      end
      
      def run_body(start=0)  # :yields: cur, total, comments_hash
        while start < @maxid
          data = run_GET('body', start)
          parsed = LiveJournal::Sync::CommentsXML::Parser.new(data)
          break if parsed.comments.empty?
          cur = parsed.comments.keys.max
          yield cur, @maxid, parsed
          start = cur + 1
        end
      end
    end
  end
end

# vim: ts=2 sw=2 et :
