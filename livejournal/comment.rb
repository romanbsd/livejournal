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
# LiveJournal comments.

# http://www.livejournal.com/developer/exporting.bml

module LiveJournal
  class Comment
    attr_accessor :commentid, :posterid, :itemid, :parentid
    # State of the comment.  Possible values: {+:active+, +:screened+, +:deleted+}
    attr_accessor :state 
    attr_accessor :subject, :body
    # a Ruby Time object
    attr_reader   :time

    def initialize
      @commentid = @posterid = @itemid = @parentid = nil
      @subject = @body = nil
      @time = nil
      @state = :active
    end

    # Convert a state to the string representation used by LiveJournal.
    def self.state_from_string(str)
      case str
      when nil; :active
      when 'A'; :active
      when 'D'; :deleted
      when 'S'; :screened
      else raise ArgumentError, "Invalid comment state: #{str.inspect}"
      end
    end

    # Convert a state from the string representation used by LiveJournal.
    def self.state_to_string state
      case state
      when nil;       nil
      when :active;   nil
      when :deleted;  'D'
      when :screened; 'S'
      else raise ArgumentError, "Invalid comment state: #{state.inspect}"
      end
    end

    def time=(time)
      raise RuntimeError, "Must use GMT times everywhere to reduce confusion.  See LiveJournal::coerce_gmt for details." unless time.gmt?
      @time = time
    end

    def ==(other)
      [:commentid, :posterid, :state, :itemid, :parentid,
       :subject, :body, :time].each do |attr|
        return false if send(attr) != other.send(attr)
      end
      return true
    end
  end
end

# vim: ts=2 sw=2 et :
