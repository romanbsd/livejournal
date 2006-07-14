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

$:.unshift '../lib'
require 'livejournal/comments-xml'
require 'rexml/document'
require 'test/unit'

TEST_COMMENTS_META = %q{<?xml version="1.0" encoding='utf-8'?>
<livejournal>
<maxid>421</maxid>
<comments>
<comment id='421' posterid='1129145' />
<comment id='420' />
</comments>
<usermaps>
<usermap id='1129145' user='cumbum' />
</usermaps>
</livejournal>
}

TEST_COMMENTS_BODY = %q{<?xml version="1.0" encoding='utf-8'?>
<livejournal>
<comments>
<comment id='1' jitemid='1' posterid='157893'>
<body>fuck yeah!!!!  rock on with your GTK client, man.</body>
<date>2001-07-26T18:16:19Z</date>
</comment>
<comment id='2' jitemid='1' posterid='1571' state='D' parentid='1' />
<comment id='4' jitemid='144' posterid='1'>
<subject>/me wants</subject>
<body>dude, you updating the CVS server?  i wanna track these changes.... 

and is it going to be resizable?
</body>
<date>2000-04-01T18:58:01Z</date>
</comment>
<comment id='999' jitemid='622' posterid='1594' parentid='998'>
<body>I agree</body>
<date>2000-08-01T15:37:55Z</date>
</comment>
</comments>
</livejournal>
}

class TC_Parsers < Test::Unit::TestCase
  def run_meta(parser)
    parser.parse TEST_COMMENTS_META

    assert_equal(421, parser.maxid)

    assert_equal(2, parser.comments.keys.length)
    assert_equal(1129145, parser.comments[421].posterid)
    assert_equal(nil, parser.comments[420].posterid)

    assert_equal('cumbum', parser.usermap[1129145])
    assert_equal(1, parser.usermap.keys.length)
  end

  def run_body(parser)
    parser.parse TEST_COMMENTS_BODY

    assert_equal(1, parser.comments[2].itemid)
    assert_equal(:active, parser.comments[1].state)
    assert_equal(:deleted, parser.comments[2].state)
    assert_equal(1, parser.comments[2].parentid)
    assert_equal('/me wants', parser.comments[4].subject)
    assert_equal('I agree', parser.comments[999].body)
    assert_equal(nil, parser.comments[999].subject)

    assert_equal(2001, parser.comments[1].time.year)
    assert_equal(7, parser.comments[1].time.mon)
    assert_equal(26, parser.comments[1].time.day)
    assert_equal(18, parser.comments[1].time.hour)
  end

  def test_rexml
    run_meta LiveJournal::Sync::CommentsXML::WithREXML.new
    run_body LiveJournal::Sync::CommentsXML::WithREXML.new
  end
  def test_expat
    if LiveJournal::HAVE_XML_PARSER
      run_meta LiveJournal::Sync::CommentsXML::WithExpat.new
      run_body LiveJournal::Sync::CommentsXML::WithExpat.new
    end
  end
end

# vim: ts=2 sw=2 et :
