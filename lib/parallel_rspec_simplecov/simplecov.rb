require "simplecov"
require "rspec"
require "parallel_rspec/config"

module ParallelRSpec::SimpleCov
  @simplecov_enabled = false
  @simplecov_base_dir = nil
  @simplecov_formatters = []

  # Returns true once {.start} has been called in this process.
  #
  # @return [Boolean]
  def self.simplecov_enabled?
    @simplecov_enabled
  end

  # Configure SimpleCov to merge coverage across `parallel_rspec` workers.
  #
  # Call this in place of `SimpleCov.start` from your `spec_helper.rb`. It
  # starts SimpleCov on the server process, registers an `after_fork` hook
  # so each worker writes its own resultset under `coverage/rspec_N/`, and
  # registers an `after(:suite)` hook to collate everything into a merged
  # report at the end of the run.
  #
  # Idempotent: subsequent calls are no-ops.
  #
  # @param profile [String, nil] SimpleCov profile name, passed through to `SimpleCov.start`.
  # @param formatters [Array<SimpleCov::Formatter>, nil] formatters to apply to the merged result. Accepts formatter classes or instances. When more than one is given they are wrapped in a `MultiFormatter`. When omitted, SimpleCov's default formatter is used.
  # @yield SimpleCov configuration block (e.g. `add_filter`, `enable_coverage :branch`), passed through to `SimpleCov.start`.
  # @return [void]
  def self.start(profile = nil, formatters: nil, &block)
    return if @simplecov_enabled

    ::SimpleCov.enable_for_subprocesses true

    base_dir = ::SimpleCov.coverage_dir

    force_worker_settings = lambda do
      # Prevent forked processes races generating the HTML report; each
      # process just dumps a .resultset.json that the runner collates into
      # the user's chosen formatter(s) at the end of the run.
      ::SimpleCov.print_error_status = false
      ::SimpleCov.formatter ::SimpleCov::Formatter::SimpleFormatter
      ::SimpleCov.minimum_coverage 0
    end

    start_simplecov = lambda do |command_name, dir|
      ::SimpleCov.command_name command_name
      ::SimpleCov.coverage_dir dir
      ::SimpleCov.start(profile, &block)
    end

    ParallelRSpec::Config.after_fork do |worker_number|
      force_worker_settings.call
      start_simplecov.call(
        "RSpec Worker #{worker_number}",
        File.join(base_dir, "rspec_#{worker_number}"),
      )
    end

    RSpec.configuration.after(:suite) do
      ParallelRSpec::SimpleCov.collate!
    end

    force_worker_settings.call
    start_simplecov.call("RSpec Server", File.join(base_dir, "rspec_server"))

    @simplecov_base_dir = base_dir
    @simplecov_formatters = Array(formatters)
    @simplecov_enabled = true
  end

  # Merge per-worker resultsets into a single report. Called automatically
  # from the `after(:suite)` hook installed by {.start} — not intended to
  # be called directly.
  #
  # @api private
  # @return [void]
  def self.collate!
    base_dir = @simplecov_base_dir || ::SimpleCov.coverage_dir

    # Force the server process's resultset to disk before we glob. SimpleCov's
    # own at_exit handler will harmlessly re-dump it after collation finishes.
    ::SimpleCov.result.format!

    pattern = File.join(base_dir, "rspec_*", ".resultset.json")
    resultsets = Dir.glob(pattern)

    if resultsets.empty?
      warn "[parallel_rspec] no SimpleCov resultsets found under #{pattern}; skipping collation"
      return
    end

    collate_formatter =
      case @simplecov_formatters.length
      when 0 then nil
      when 1 then @simplecov_formatters.first
      else ::SimpleCov::Formatter::MultiFormatter.new(@simplecov_formatters)
      end

    ::SimpleCov.collate(resultsets) do
      coverage_dir base_dir
      formatter collate_formatter if collate_formatter
    end
  rescue => e
    warn "[parallel_rspec] simplecov collation failed: #{e.class}: #{e.message}"
    warn e.backtrace.first(5).join("\n") if e.backtrace
  end
end
