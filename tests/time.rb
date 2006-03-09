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
require 'test/unit'

class TC_Times < Test::Unit::TestCase
  def test_roundtrip
    now = Time.now
    ljtime = LiveJournal::Request::time_to_ljtime(now)
    roundtrip = LiveJournal::Request::ljtime_to_time(ljtime)
    [:year, :mon, :day, :hour, :min].each do |field|
      assert_equal(now.send(field), roundtrip.send(field))
    end
  end

  def test_parse
    ljtime = "2005-12-27 14:50"
    time = LiveJournal::Request::ljtime_to_time(ljtime)
    assert_equal(time.year, 2005)
    assert_equal(time.mon, 12)
    assert_equal(time.day, 27)
    assert_equal(time.hour, 14)
    assert_equal(time.min, 50)
  end
end

# vim: ts=2 sw=2 et :
