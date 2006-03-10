#!/usr/bin/ruby

require 'livejournal/login'
require 'livejournal/entry'
require 'test/unit'

class TC_Login < Test::Unit::TestCase
  def setup
    @user = LiveJournal::User.new('test', 'test')
  end

  def test_login
    login = LiveJournal::Request::Login.new(@user)
    login.run
    assert_not_equal(@user.fullname, nil)
  end
end

# vim: ts=2 sw=2 et :
