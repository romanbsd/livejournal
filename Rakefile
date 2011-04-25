require 'rake'
require 'rake/gempackagetask'
require 'rake/packagetask'
require 'rake/rdoctask'
require 'rake/testtask'

FILES = FileList[
  'Rakefile', 'README.md', 'Changes', 'LICENSE', 'setup.rb', 'VERSION',
  'lib/**/*', 'sample/*', 'test/*'
]

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
    gem.name = 'livejournal'
    gem.summary = 'Module for interacting with livejournal'
    gem.description = %q{LiveJournal module.  Post to livejournal, retrieve friends lists, edit entries, sync journal to an offline database.}
    gem.email = 'romanbsd@yahoo.com'
    gem.homepage = 'http://neugierig.org/software/livejournal/ruby/'
    gem.authors = ['Evan Martin', 'Roman Shterenzon']
    gem.files = FILES.to_a
  end
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end

desc 'Generate RDoc'
Rake::RDocTask.new :rdoc do |rd|
  rd.title = "ljrb (LiveJournal Ruby module) Documentation"
  rd.rdoc_dir = 'doc'
  rd.rdoc_files.add 'lib/livejournal/*.rb', 'README.md', 'LICENSE'
  rd.main = 'README.md'
end

desc 'Run Tests'
Rake::TestTask.new :test do |t|
  t.test_files = FileList['test/*.rb']
end

# vim: set ts=2 sw=2 et :
