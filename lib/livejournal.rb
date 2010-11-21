require 'livejournal/entry'
require 'livejournal/login'

module LiveJournal
  VERSION = File.read(File.expand_path('../../VERSION',__FILE__)).chomp.freeze
end