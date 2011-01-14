# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "spare/version"

Gem::Specification.new do |s|
  s.name        = "spare"
  s.version     = Spare::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Simon Menke"]
  s.email       = ["simon.menke@gmail.com"]
  s.homepage    = "https://github.com/fd/spare"
  s.summary     = %q{Rake tasks for making backups}
  s.description = %q{Simple backup system for Rake}

  s.rubyforge_project = "spare"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.add_runtime_dependency 'rake', ">= 0.8.7"
end
