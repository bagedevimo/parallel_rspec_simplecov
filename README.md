# ParallelRSpec::SimpleCov

A very small library for collecting SimpleCov coverage from RSpec suites run in parallel via [parallel_rspec](https://github.com/willbryant/parallel_rspec).

SimpleCov doesn't merge coverage across `parallel_rspec`'s forked workers by default; this gem registers an `after_fork` hook so each worker writes its own resultset, then collates them in `after(:suite)`.

## Installation

```bash
bundle add parallel_rspec_simplecov
```

## Usage

Replace your call (in `spec_helper.rb`, for example) to `SimpleCov.start` with a call to `ParallelRSpec::SimpleCov.start`. It accepts the same positional `profile` argument and configuration block as `SimpleCov.start`, plus a `formatters:` keyword listing the formatters to apply to the *merged* result.

```ruby
ParallelRSpec::SimpleCov.start(
  'rails',
  formatters: [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CoberturaFormatter,
  ]
) do
  enable_coverage :branch
  add_filter '/spec/'
  add_filter '/config/'
end
```

## Output

Per-worker resultsets land in `coverage/rspec_N/`; the merged result and any formatter output (HTML, Cobertura, …) end up at the top level of `coverage/`.
