#!/usr/bin/ruby

# Contributed by Dusty Matthews, fixed up by Evan.

require 'livejournal/login'
require 'livejournal/friends'
require 'test/unit'

class TC_CheckFriends < Test::Unit::TestCase
  def setup
    @user = LiveJournal::User.new('test','test')
  end

  def test_true
    # Absurd date that will always be true.
    checkfriend = LiveJournal::Request::CheckFriends.new(@user, "2000-01-10 12:40:00")
    new = checkfriend.run
    assert(new)
  end

  def test_false
    # Absurd date that will always be false.
    checkfriend = LiveJournal::Request::CheckFriends.new(@user, "2010-01-10 12:40:00")
    new = checkfriend.run
    assert(!new)
  end
end

# vim: ts=2 sw=2 et :
