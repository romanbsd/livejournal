require 'rake'
require 'rake/gempackagetask'
require 'rake/packagetask'
require 'rake/rdoctask'
require 'rake/testtask'

PKG_NAME = 'livejournal'
PKG_VERSION = '0.0.1'

FILES = FileList[
  'Rakefile', 'README', 'LICENSE', 'setup.rb',
  'lib/**', 'sample/**', 'test/**'
]

desc 'Build Package'
Rake::PackageTask.new 'package' do |p|
  p.name = PKG_NAME
  p.version = PKG_VERSION
  p.package_files = FILES
  p.need_tar = true
  p.need_zip = true
end

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
  s.require_path = 'lib'
end

Rake::GemPackageTask.new(spec)

desc 'Generate RDoc'
Rake::RDocTask.new :rdoc do |rd|
  rd.title = "ljrb (LiveJournal Ruby module) Documentation"
  rd.rdoc_dir = 'doc'
  rd.rdoc_files.add 'lib', 'README', 'LICENSE'
  rd.main = 'README'
end

desc 'Build Gem'
Rake::GemPackageTask.new spec do |pkg|
  pkg.need_tar = true
end

desc 'Run Tests'
Rake::TestTask.new :test do |t|
  t.test_files = FileList['test/*.rb']
end

desc 'Push data to my webspace'
task :pushweb => [:package] do
  pkg = "pkg/#{PKG_NAME}-#{PKG_VERSION}"
  target = 'neugierig.org:/home/martine/www/neugierig/htdocs/software/livejournal/ruby'
  sh %{rsync -av --delete doc/* #{target}/doc/}
  sh %{rsync -av #{pkg}.* #{target}/download/}
end

desc 'Push everything'
task :push => [:pushweb]  # XXX push to rubyforge

# vim: set ts=2 sw=2 et :
