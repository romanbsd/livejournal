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
    attr_accessor :background, :foreground, :groupmask, :type
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
      @type = req['type']
      self
    end
    def to_s
      "#{@username}: #{@fullname}"
    end
  end

  module Request
    class Friends < Req
      attr_reader :friends
      def initialize(user)
        super(user, 'getfriends')
        @friends = nil
      end
      # Returns an array of LiveJournal::Friend.
      def run
        super
        @friends = build_array('friend') { |r| Friend.new.from_request(r) }
        @friends
      end
    end
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

    class CheckFriends < Req
      attr_reader :interval
      def initialize(user, lastupdate=nil)
        super(user, 'checkfriends')
        @lastupdate = lastupdate
        @interval = 90   # reasonable default?
      end
      # Returns true if there are new posts available.
      def run
        self['lastupdate'] = @lastupdate if @lastupdate
        super
        @lastupdate = self['lastupdate']
        @interval = self['interval']
        self['new'] == '1'
      end
    end
  end
end

# vim: ts=2 sw=2 et :
