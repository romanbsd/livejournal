require 'rake'
require 'rake/gempackagetask'
require 'rake/packagetask'
require 'rake/rdoctask'
require 'rake/testtask'

PKG_NAME = 'livejournal'
PKG_VERSION = '0.3.1'

FILES = FileList[
  'Rakefile', 'README', 'Changes', 'LICENSE', 'setup.rb',
  'lib/**/*', 'sample/*', 'test/*'
]

spec = Gem::Specification.new do |s|
  s.name = PKG_NAME
  s.version = PKG_VERSION
  s.summary = 'module for interacting with livejournal'
  s.description = %q{LiveJournal module.  Post to livejournal, retrieve friends
lists, edit entries, sync journal to an offline database.}
  s.author = 'Evan Martin'
  s.email = 'martine@danga.com'
  s.homepage = 'http://neugierig.org/software/livejournal/ruby/'

  s.has_rdoc = true
  s.files = FILES.to_a
end

desc 'Build Package'
Rake::GemPackageTask.new(spec) do |p|
  p.need_tar = true
  p.need_zip = true
end


desc 'Generate RDoc'
Rake::RDocTask.new :rdoc do |rd|
  rd.title = "ljrb (LiveJournal Ruby module) Documentation"
  rd.rdoc_dir = 'doc'
  rd.rdoc_files.add 'lib/livejournal/*.rb', 'README', 'LICENSE'
  rd.main = 'README'
end

desc 'Run Tests'
Rake::TestTask.new :test do |t|
  t.test_files = FileList['test/*.rb']
end

desc 'Push data to my webspace'
task :pushweb => [:rdoc, :package] do
  pkg = "pkg/#{PKG_NAME}-#{PKG_VERSION}"
  target = 'neugierig.org:/home/martine/www/neugierig/htdocs/software/livejournal/ruby'
  sh %{rsync -av --delete doc/* #{target}/doc/}
  sh %{rsync -av #{pkg}.* #{target}/download/}
end

desc 'Push everything'
task :push => [:pushweb]  # XXX push to rubyforge

# vim: set ts=2 sw=2 et :
