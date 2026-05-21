require "parallel_rspec_simplecov"
require "fileutils"
require "tmpdir"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
