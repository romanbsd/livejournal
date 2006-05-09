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


require 'livejournal/basic'
require 'cgi'
require 'net/http'
require 'date'
require 'digest/md5'

module LiveJournal
  module Request
    class ProtocolException < RuntimeError; end

    # ljtimes look like 2005-12-04 10:24:00.
    # Convert a Time to an ljtime.
    def self.time_to_ljtime time
      time.strftime '%Y-%m-%d %H:%M:%S'
    end
    # Convert an ljtime to a Time.
    def self.ljtime_to_time str
      dt = DateTime.strptime(str, '%Y-%m-%d %H:%M')
      Time.gm(dt.year, dt.mon, dt.day, dt.hour, dt.min, 0, 0)
    end

    # wrapper around a given hash, prefixing all key lookups with base
    class HashStrip #:nodoc:
      def initialize(base, hash)
        @base = base
        @hash = hash
      end
      def [](key)
        @hash[@base + key]
      end
    end

    # Superclass for all LiveJournal requests.
    class Req #:nodoc:
      def initialize(user, mode)
        @user = user
        @request = { 'mode'          => mode,
                     'clientversion' => 'Ruby',
                     'ver'           => 1 }
        if user
          challenge = GetChallenge.new.run
          response = Digest::MD5.hexdigest(challenge +
                       Digest::MD5.hexdigest(user.password))
          @request.update({ 'user'           => user.username,
                            'auth_method'    => 'challenge',
                            'auth_challenge' => challenge,
                            'auth_response'  => response })
          @request['usejournal'] = user.usejournal if user.usejournal
        end
        @result = {}
        @verbose = false
        @dryrun = false
      end

      def verbose!; @verbose = true; end
      def dryrun!; @dryrun = true; end

      def run
        h = Net::HTTP.new('www.livejournal.com')
        h.set_debug_output $stderr if @verbose
        request = @request.collect { |key, value|
          "#{CGI.escape(key)}=#{CGI.escape(value.to_s)}"
        }.join("&")
        p request if @verbose
        return if @dryrun
        response, data = h.post('/interface/flat', request)
        parseresponse(data)
        dumpresponse if @verbose
        if @result['success'] != "OK"
          raise ProtocolException, @result['errmsg']
        end
      end

      def dumpresponse
        @result.keys.sort.each { |key| puts "#{key} -> #{@result[key]}" }
      end

      protected
      def parseresponse(data)
        lines = data.split(/\r?\n/)
        @result = {}
        0.step(lines.length-1, 2) do |i|
          @result[lines[i]] = lines[i+1]
        end
      end

      def each_in_array(base)
        for i in 1..(@result["#{base}_count"].to_i) do
          yield HashStrip.new("#{base}_#{i.to_s}_", @result)
        end
      end
      def build_array(base)
        array = []
        each_in_array(base) { |x| array << yield(x) }
        array
      end
    end

    # Used for LiveJournal's challenge-response based authentication,
    # and used by ljrb for all requests.
    class GetChallenge < Req
      def initialize
        super(nil, 'getchallenge')
      end
      # Returns the challenge.
      def run
        super
        return @result['challenge']
      end
    end
  end
end

# vim: ts=2 sw=2 et cino=(0 :
