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
  # Represents a LiveJournal friend relationship.
  # See LiveJournal::Request::Friends to get an array of these.
  class Friend
    attr_accessor :username, :fullname
    # as HTML color, like '#ff0000'
    attr_accessor :background, :foreground
    # bitfield of friend groups this friend is a member of
    attr_accessor :groupmask
    # friend type. possible values: :community, :news, :syndicated, :shared, :user
    attr_accessor :type
    def initialize
      @username = nil
      @fullname = nil
      @background = nil
      @foreground = nil
      @groupmask = nil
      @type = nil
    end
    def from_request(req)
      @username = req['user']
      @fullname = req['name']
      @foreground = req['fg']
      @background = req['bg']
      @groupmask = req['groupmask']
      @type =
        case req['type']
          when 'community';  :community
          when 'news';       :news
          when 'syndicated'; :syndicated
          when 'shared';     :shared
          when nil;          :user
          else raise LiveJournal::Request::ProtocolException.new(
                       "unknown friend type: #{req['type']}")
        end
      self
    end
    def to_s
      "#{@username}: #{@fullname}"
    end
  end

  module Request
    class Friends < Req
      attr_reader :friends, :friendofs
      # Allowed options:
      # :include_friendofs => true:: also fill out @friendofs in single request
      def initialize(user, opts={})
        super(user, 'getfriends')
        @friends = nil
        @friendofs = nil
        @request['includefriendof'] = true if opts.has_key? :include_friendofs
      end
      # Returns an array of LiveJournal::Friend.
      def run
        super
        @friends = build_array('friend') { |r| Friend.new.from_request(r) }
        @friendofs = build_array('friendof') { |r| Friend.new.from_request(r) }
        @friends
      end
    end

    # See Friends to fetch both friends and friend-ofs in one request.
    class FriendOfs < Req
      attr_reader :friendofs
      def initialize(user)
        super(user, 'friendof')
        @friendofs = nil
      end
      # Returns an array of LiveJournal::Friend.
      def run
        super
        @friends = build_array('friendof') { |r| Friend.new.from_request(r) }
        @friends
      end
    end

    # An example of polling for friends list updates.
    #   req = LiveJournal::Request::CheckFriends.new(user)
    #   req.run   # always will return false on the first run.
    #   loop do
    #     puts "Waiting for new entries..."
    #     sleep req.interval   # uses the server-recommended sleep time.
    #     break if req.run == true
    #   end
    #   puts "#{user.username}'s friends list has been updated!"
    class CheckFriends < Req
      # The server-recommended number of seconds to wait between running this.
      attr_reader :interval
      # If you want to keep your CheckFriends state without saving the object,
      # save the #lastupdate field and pass it to a new object.
      attr_reader :lastupdate
      def initialize(user, lastupdate=nil)
        super(user, 'checkfriends')
        @lastupdate = lastupdate
        @interval = 90   # reasonable default?
      end
      # Returns true if there are new posts available.
      def run
        @request['lastupdate'] = @lastupdate if @lastupdate
        super
        @lastupdate = @result['lastupdate']
        @interval = @result['interval'].to_i
        @result['new'] == '1'
      end
    end
  end
end

# vim: ts=2 sw=2 et :
