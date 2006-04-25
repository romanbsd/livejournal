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
# REXML is pleasant to use but hella slow, so we allow using the expat-based
# parser as well.

require 'livejournal/comment'
require 'time'  # parsing xmlschema times

module LiveJournal
  begin
    require 'xml/parser'
    HAVE_XML_PARSER = true
  rescue Exception
    require 'rexml/document'
    HAVE_XML_PARSER = false
  end

  module Sync
    module CommentsXML
      def self.optional_int_string(x)
        return nil unless x
        x.to_i
      end

      def self.load_comment_from_attrs(comment, attrs)
        comment.commentid = attrs['id'].to_i
        comment.posterid = CommentsXML::optional_int_string attrs['posterid']
        comment.itemid   = CommentsXML::optional_int_string attrs['jitemid']
        comment.parentid = CommentsXML::optional_int_string attrs['parentid']
        statestr = attrs['state']
        comment.state    = LiveJournal::Comment::state_from_string(statestr) if statestr
      end

      class Base
        attr_reader :maxid, :comments, :usermap
        def initialize(data=nil)
          @maxid = nil
          @comments = {}
          @usermap = {}
          parse data if data
        end
      end

      class WithREXML < Base
        def parse(data)
          doc = REXML::Document.new(data)
          root = doc.root
          
          root.elements.each('maxid') { |e| @maxid = e.text.to_i }

          root.elements.each('comments/comment') do |e|
            id = e.attributes['id'].to_i
            comment = @comments[id] || Comment.new
            CommentsXML::load_comment_from_attrs(comment, e.attributes)
            e.elements.each('subject') { |s| comment.subject = s.text }
            e.elements.each('body') { |s| comment.body = s.text }
            e.elements.each('date') { |s| comment.time = Time::xmlschema s.text }
            @comments[id] = comment
          end

          root.elements.each('usermaps/usermap') do |e|
            id = e.attributes['id'].to_i
            user = e.attributes['user']
            @usermap[id] = user
          end
        end
      end

      if HAVE_XML_PARSER
        class WithExpat < Base
          class Parser < XMLParser
            attr_reader :maxid, :comments, :usermap
            def initialize
              super
              @maxid = nil
              @cur_comment = nil
              @comments = {}
              @usermap = {}
              @content = nil
            end
            def startElement(name, attrs)
              case name
              when 'maxid'
                @content = ''
              when 'comment'
                id = attrs['id'].to_i
                @cur_comment = @comments[id] || Comment.new
                @comments[id] = @cur_comment
                CommentsXML::load_comment_from_attrs(@cur_comment, attrs)
              when 'usermap'
                id = attrs['id'].to_i
                user = attrs['user']
                @usermap[id] = user
              when 'date'
                @content = ''
              when 'subject'
                @content = ''
              when 'body'
                @content = ''
              end
            end
            def character(data)
              @content << data if @content
            end
            def endElement(name)
              return unless @content
              case name
              when 'maxid'
                @maxid = @content.to_i
              when 'date'
                @cur_comment.time = Time::xmlschema(@content)
              when 'subject'
                @cur_comment.subject = @content
              when 'body'
                @cur_comment.body = @content
              end
              @content = nil
            end
          end
          def parse(data)
            parser = Parser.new
            parser.parse(data)
            @maxid = parser.maxid
            @comments = parser.comments
            @usermap = parser.usermap
          end
        end  # class WithExpat
      end  # if HAVE_XML_PARSER

      if HAVE_XML_PARSER
        Parser = WithExpat
      else
        Parser = WithREXML
      end
    end  # module CommentsXML
  end  # module Sync
end  # module LiveJournal

# vim: ts=2 sw=2 et :
