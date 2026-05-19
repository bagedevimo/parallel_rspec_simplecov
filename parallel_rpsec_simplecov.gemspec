# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'parallel_rspec_simplecov/version'

Gem::Specification.new do |spec|
  spec.name          = "parallel_rspec_simplecov"
  spec.version       = ParallelRSpec::SimpleCov::VERSION
  spec.authors       = ["Ben Anderson"]
  spec.email         = ["me@benanderson.nz"]

  spec.summary       = %q{Collect and colloate simplecov coverage reports when using parallel_rspec}
  spec.description   = %q{Collect and colloate simplecov coverage reports when using parallel_rspec}
  spec.homepage      = "https://github.com/bagedevimo/parallel_rspec_simplecov"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "parallel_rspec"
  spec.add_dependency "rspec"
  spec.add_dependency "simplecov"
end

