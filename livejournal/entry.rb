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

require 'livejournal/request'

module LiveJournal
  # LiveJournal times have no time zone, as they are for display only:
  # "I wrote this post at midnight".  However, it's convenient to represent
  # times with a Ruby time object.  But when time zones get involved,
  # everything gets confused; we'd like to store a Unix time in the database
  # and those only make sense as GMT.  To reduce confusion, then, we imagine
  # all LiveJournal times are in GMT.
  # This function takes a time in any time zone and just switches the
  # timezone to GMT.  That is, coerce_gmt of 11:12pm PST is 11:12 pm GMT.
  # The entry time-setting functions require this GMT part to verify you're
  # thinking carefully about time when you use Entry#time.  If I want an
  # entry that has a time that corresponds to what I feel is "now", I'd use
  #  LiveJournal::coerce_gmt Time.now
  def self.coerce_gmt time
    expanded = time.to_a
    expanded[8] = false  # dst flag
    expanded[9] = 'GMT'
    return Time.gm(*expanded)
  end

  class Entry
    attr_accessor :itemid, :anum, :subject, :event, :moodid, :mood
    attr_accessor :music, :taglist, :pickeyword, :preformatted, :backdated
    attr_accessor :comments  # values: {:normal, :none, :noemail}
    attr_reader :time  # a Ruby Time object
    attr_accessor :security  # values: {:public, :private, :friends, :custom}
    attr_accessor :allowmask
    attr_accessor :screening # values {:default, :all, :anonymous, :nonfriends, :none}
    attr_accessor :props

    def initialize
      @subject = nil
      @event = nil
      @moodid = nil
      @mood = nil
      @music = nil
      @taglist = []
      @pickeyword = nil
      @preformatted = false
      @backdated = false
      @comments = :normal
      @time = nil
      @security = :public
      @allowmask = nil
      @screening = :default
      @props = {}
    end

    def ==(other)
      [:subject, :event, :moodid, :mood, :music, :taglist, :pickeyword,
       :preformatted, :backdated, :comments, :time, :security, :allowmask,
       :screening, :props].each do |attr|
        return false if send(attr) != other.send(attr)
      end
      return true
    end

    def time=(time)
      raise RuntimeError, "Must use GMT times everywhere to reduce confusion.  See LiveJournal::coerce_gmt for details." unless time.gmt?
      @time = time
    end

    def from_request(req)
      @itemid, @anum = req['itemid'].to_i, req['anum'].to_i
      @subject, @event = req['subject'], CGI.unescape(req['event'])

      case req['security']
      when 'public'
        @security = :public
      when 'private'
        @security = :private
      when 'usemask'
        if req['allowmask'] == '1'
          @security = :friends
        else
          @security = :custom
          @allowmask = req['allowmask'].to_i
        end
      end

      @time = LiveJournal::Request::ljtime_to_time req['eventtime']

      # further metadata is loaded via #load_prop

      self
    end
    def load_prop(name, value) #:nodoc:#
      case name
      when 'current_mood'
        @mood = value.to_i
      when 'current_moodid'
        @moodid = value.to_i
      when 'current_music'
        @music = value
      when 'taglist'
        @taglist = value.split(/, /).sort
      when 'picture_keyword'
        @pickeyword = value
      when 'opt_preformatted'
        @preformatted = value == '1'
      when 'opt_nocomments'
        @comments = :none
      when 'opt_noemail'
        @comments = :noemail
      when 'opt_backdated'
        @backdated = value == '1'
      when 'opt_screening'
        case value
        when 'A'; @screening = :all
        when 'R'; @screening = :anonymous
        when 'F'; @screening = :nonfriends
        when 'N'; @screening = :none
        else
          raise LiveJournalException,
            "unknown opt_screening value #{value.inspect}"
        end
      when 'hasscreened'
        @screened = value == '1'
      # and then some props we just store by name
      when 'revnum';       @props[name] = value
      when 'revtime';      @props[name] = value
      when 'commentalter'; @props[name] = value
      when 'unknown8bit';  @props[name] = value
      else
        @props[name] = value
        raise Request::ProtocolException, "unknown prop (#{name}, #{value})"
      end
    end

    # Get the numeric id used in URLs (it's a function of the itemid and the
    # anum).
    def display_itemid
      (@itemid << 8) + @anum
    end

    # Render LJ markup to an HTML simulation.
    # (The server to use is for rendering links to other LJ users.)
    def event_as_html server=LiveJournal::DEFAULT_SERVER
      # I'd like to use REXML but the content isn't XML, so REs it is!
      html = @event.dup
      html.gsub!(/\n/, "<br/>\n") unless @preformatted
      html.gsub!(%r{< \s* lj \s+ user \s* = \s*
                    ['"]? ([^\s'"]+) ['"]?
                    \s* /? \s* >}ix) do
        user = $1
        url = "#{server.url}/~#{user}/"
        "<a href='#{url}'><b>#{user}</b></a>"
      end
      html
    end
  end

  module Request
    class GetEvents < Req
      # We support three different types of GetEvents:
      # * <tt>GetEvents.new(user, :itemid => itemid)</tt> (fetch a single item)
      # * <tt>GetEvents.new(user, :recent => n)</tt> (fetch most recent n itemds)
      # * <tt>GetEvents.new(user, :lastsync => lastsync)</tt> (for syncing)
      def initialize(user, opts)
        super(user, 'getevents')
        self['lineendings'] = 'unix'

        if opts.has_key? :itemid
          self['selecttype'] = 'one'
          self['itemid'] = opts[:itemid]
        elsif opts.has_key? :recent
          self['selecttype'] = 'lastn'
          self['howmany'] = opts[:recent]
        elsif opts.has_key? :lastsync
          self['selecttype'] = 'syncitems'
          self['lastsync'] = opts[:lastsync] if opts[:lastsync]
        end
      end

      # Returns either a single #Entry or an array of #Entry, depending on
      # the mode this was constructed with.
      def run
        super

        entries = {}
        each_in_array('events') do |req|
          entry = Entry.new.from_request(req)
          entries[entry.itemid] = entry
        end

        each_in_array('prop') do |prop|
          itemid = prop['itemid'].to_i
          entries[itemid].load_prop(prop['name'], prop['value'])
        end

        if @reqparams.has_key? 'itemid'
          return entries[@reqparams['itemid']]
        else
          return entries
        end
      end
    end
    class EditEvent < Req
      def initialize(user, entry, opts={})
        super(user, 'editevent')
        self['itemid'] = entry.itemid
        if entry.event
          self['event'] = entry.event
        elsif entry.entry.nil? and opts.has_key? :delete
          self['event'] = ''
        else
          raise AccidentalDeleteError
        end
        self['lineendings'] = 'unix'
        self['subject'] = entry.subject

        case entry.security
        when :public
          self['security'] = 'public'
        when :friends
          self['security'] = 'usemask'
          self['allowmask'] = 1
        when :private
          self['security'] = 'private'
        when :custom
          self['security'] = 'usemask'
          self['allowmask'] = entry.allowmask
        end

        self['year'], self['mon'], self['day'] = 
          entry.time.year, entry.time.mon, entry.time.day
        self['hour'], self['min'] = entry.time.hour, entry.time.min

        { 'current_mood' => entry.mood,
          'current_moodid' => entry.moodid,
          'current_music' => entry.music,
          'picture_keyword' => entry.pickeyword,
          'taglist' => entry.taglist.join(', '),
          'opt_preformatted' => entry.preformatted ? 1 : 0,
          'opt_nocomments' => entry.comments == :none ? 1 : 0,
          'opt_noemail' => entry.comments == :noemail ? 1 : 0,
          'opt_backdated' => entry.backdated ? 1 : 0,
          'opt_screening' =>
            case entry.screening
            when :all; 'A'
            when :anonymous; 'R'
            when :nonfriends; 'F'
            when :none; 'N'
            when :default; ''
            end
        }.each do |name, value|
          self["prop_#{name}"] = value
        end
      end
    end
  end
end

# vim: ts=2 sw=2 et :
