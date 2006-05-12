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
# This module extends the LiveJournal module to work with LogJam's data.
# XXX this is currently not working due to database schema divergence

require 'rexml/document'    # parsing logjam conf

module LiveJournal
  # XXX this is currently not working due to database schema divergence
  module LogJam
    # Path to LogJam data.
    def self.logjam_path
      File.expand_path '~/.logjam'
    end

    def self.xml_fetch(file, path)  #:nodoc:
      doc = REXML::Document.new(File.open(file))
      doc.elements.each(path) { |element| return element.text }
      return nil
    end

    # Name of LogJam's current server.
    def self.current_server
      xml_fetch(logjam_path + '/conf.xml', '/configuration/currentserver')
    end

    # Path to LogJam's data for a given server.
    def self.server_path servername
      logjam_path + '/servers/' + servername  # is escaping needed here?
    end

    # Username for a given server's current user.
    def self.current_user servername
      xml_fetch(server_path(servername) + '/conf.xml',
                '/server/currentuser')
    end

    # Path to a given user's data.
    def self.user_path servername, username
      server_path(servername) + "/users/#{username}"
    end

    # Return [current_server, current_user].
    def self.current_server_user
      server = current_server
      user = current_user server
      [server, user]
    end

    def self.database_from_server_user servername, username
      Database.new(LogJam::user_path(servername, username) + "/journal.db")
    end
  end
end

# vim: ts=2 sw=2 et :
