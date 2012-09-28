# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__),'lib','pushare','version.rb'])
spec = Gem::Specification.new do |s| 
  s.name = 'pushare'
  s.version = Pushare::VERSION
  s.author = 'Your Name Here'
  s.email = 'your@email.address.com'
  s.homepage = 'http://your.website.com'
  s.platform = Gem::Platform::RUBY
  s.summary = 'A description of your project'
# Add your other files here if you make them
  s.files = %w(
bin/pushare
lib/pushare/version.rb
lib/pushare/pushare.rb
lib/pushare.rb
  )
  s.require_paths << 'lib'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.rdoc','pushare.rdoc']
  s.rdoc_options << '--title' << 'pushare' << '--main' << 'README.rdoc' << '-ri'
  s.bindir = 'bin'
  s.executables << 'pushare'
  s.add_development_dependency('rake')
  s.add_development_dependency('rdoc')
  s.add_development_dependency('aruba')
  s.add_development_dependency('pry')
  s.add_development_dependency('pusher')
  s.add_development_dependency('pusher-client')
  s.add_development_dependency('msgpack')
  s.add_development_dependency('ruby-xz')
  s.add_development_dependency('Ascii85')
  s.add_development_dependency('ohai')
  s.add_runtime_dependency('gli','2.0.0')
end
