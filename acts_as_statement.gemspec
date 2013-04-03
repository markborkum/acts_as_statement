# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'acts_as_statement'

Gem::Specification.new do |spec|
  spec.name          = "acts_as_statement"
  spec.version       = ActiveRecord::Acts::Statement::VERSION
  spec.authors       = ["Mark Borkum"]
  spec.email         = ["m.i.borkum@soton.ac.uk"]
  spec.description   = "This is a pure-Ruby library for working with Resource Description Framework (RDF) data in Active Record-based applications."
  spec.summary       = "An RDF.rb quad-store for Active Record"
  spec.homepage      = "https://github.com/markborkum/acts_as_statement"
  spec.license       = "UNLICENSE"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_dependency "activerecord"
  spec.add_dependency "rdf"
end
