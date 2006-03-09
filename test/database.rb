#!/usr/bin/ruby

require 'livejournal/database'
require 'livejournal/entry'
require 'test/unit'

class TC_Database < Test::Unit::TestCase
  FILENAME = '/tmp/test.db'

  def setup
    @db = LiveJournal::Database.new(FILENAME, true)
  end

  def teardown
    @db.close
    File.delete FILENAME
  end

  def test_metas
    @db.username = 'foo'
    assert_equal(@db.username, 'foo')
  end

  def roundtrip e
    @db.store_entry e
    new_e = @db.get_entry e.itemid
    assert_equal(e, new_e)
  end

  def test_roundtrips
    e = LiveJournal::Entry.new
    e.itemid = 1
    e.anum = 2
    e.subject = 'subject here'
    e.event = 'event here'
    e.time = LiveJournal::coerce_gmt Time.now

    roundtrip e

    e = LiveJournal::Entry.new
    e.itemid = 1
    e.anum = 2
    e.subject = 'subject here'
    e.event = 'eventblah here'
    e.time = LiveJournal::coerce_gmt Time.now
    e.comments = :noemail
    e.preformatted = true
    e.security = :friends

    roundtrip e
  end
end

# vim: ts=2 sw=2 et :
