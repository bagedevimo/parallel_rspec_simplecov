RSpec.describe ParallelRSpec::SimpleCov do
  before do
    described_class.instance_variable_set(:@simplecov_enabled, false)
    described_class.instance_variable_set(:@simplecov_base_dir, nil)
    described_class.instance_variable_set(:@simplecov_formatters, [])
  end

  describe ".simplecov_enabled?" do
    it "is false before start is called" do
      expect(described_class.simplecov_enabled?).to be false
    end
  end

  describe ".start" do
    let(:after_fork_callbacks) { [] }
    let(:after_suite_hooks) { [] }

    before do
      allow(::SimpleCov).to receive(:enable_for_subprocesses)
      allow(::SimpleCov).to receive(:coverage_dir).and_return("coverage")
      allow(::SimpleCov).to receive(:command_name)
      allow(::SimpleCov).to receive(:start)
      allow(::SimpleCov).to receive(:print_error_status=)
      allow(::SimpleCov).to receive(:formatter)
      allow(::SimpleCov).to receive(:minimum_coverage)

      allow(ParallelRSpec::Config).to receive(:after_fork) do |&block|
        after_fork_callbacks << block
      end
      allow(RSpec.configuration).to receive(:after).with(:suite) do |&block|
        after_suite_hooks << block
      end
    end

    it "marks simplecov as enabled" do
      described_class.start
      expect(described_class).to be_simplecov_enabled
    end

    it "registers exactly one after_fork callback" do
      described_class.start
      expect(after_fork_callbacks.size).to eq(1)
    end

    it "registers exactly one after(:suite) hook" do
      described_class.start
      expect(after_suite_hooks.size).to eq(1)
    end

    it "is idempotent — repeated calls do not re-register hooks" do
      described_class.start
      described_class.start
      described_class.start
      expect(after_fork_callbacks.size).to eq(1)
      expect(after_suite_hooks.size).to eq(1)
    end

    describe "formatter normalization" do
      it "treats nil as an empty array" do
        described_class.start
        expect(described_class.instance_variable_get(:@simplecov_formatters)).to eq([])
      end

      it "wraps a single formatter in an array" do
        formatter = double("formatter")
        described_class.start(formatters: formatter)
        expect(described_class.instance_variable_get(:@simplecov_formatters)).to eq([formatter])
      end

      it "preserves an array of formatters" do
        formatters = [double("a"), double("b")]
        described_class.start(formatters: formatters)
        expect(described_class.instance_variable_get(:@simplecov_formatters)).to eq(formatters)
      end
    end
  end

  describe ".collate!" do
    let(:base_dir) { Dir.mktmpdir("parallel_rspec_simplecov_spec") }

    before do
      described_class.instance_variable_set(:@simplecov_base_dir, base_dir)
      allow(::SimpleCov).to receive(:result).and_return(instance_double(::SimpleCov::Result, format!: nil))
    end

    after do
      FileUtils.remove_entry(base_dir)
    end

    context "when no worker resultsets exist" do
      it "warns and skips collation" do
        allow(::SimpleCov).to receive(:collate)
        expect { described_class.collate! }.to output(/no SimpleCov resultsets found/).to_stderr
        expect(::SimpleCov).not_to have_received(:collate)
      end
    end

    context "when worker resultsets exist" do
      before do
        ["rspec_1", "rspec_2"].each do |dir|
          FileUtils.mkdir_p(File.join(base_dir, dir))
          File.write(File.join(base_dir, dir, ".resultset.json"), "{}")
        end
      end

      it "calls SimpleCov.collate with the discovered resultsets" do
        captured_paths = nil
        allow(::SimpleCov).to receive(:collate) { |paths, &_block| captured_paths = paths }

        described_class.collate!

        expect(captured_paths).to match_array([
          File.join(base_dir, "rspec_1", ".resultset.json"),
          File.join(base_dir, "rspec_2", ".resultset.json"),
        ])
      end
    end
  end
end
