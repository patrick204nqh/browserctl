# frozen_string_literal: true

require "spec_helper"
require "browserctl/orphan_sweeper"

RSpec.describe Browserctl::OrphanSweeper do
  describe ".find_orphans" do
    it "returns PIDs of ferrum-spawned chromes reparented to init" do
      ferrum_a = "Chrome --user-data-dir=/tmp/ferrum_user_data_dir_a --headless"
      ferrum_b = "Chrome --user-data-dir=/tmp/ferrum_user_data_dir_b"
      processes = [
        { pid: 100, ppid: 1,   command: ferrum_a },
        { pid: 200, ppid: 1,   command: ferrum_b },
        { pid: 300, ppid: 500, command: "Chrome --user-data-dir=/tmp/ferrum_user_data_dir_live" },
        { pid: 400, ppid: 1,   command: "Chrome --user-data-dir=/some/other/profile" }
      ]

      expect(described_class.find_orphans(processes)).to contain_exactly(100, 200)
    end

    it "ignores ferrum-spawned chromes whose parent is still alive" do
      processes = [
        { pid: 100, ppid: 12_345, command: "Chrome --user-data-dir=/tmp/ferrum_user_data_dir_live" }
      ]

      expect(described_class.find_orphans(processes)).to be_empty
    end

    it "returns nothing for an empty process list" do
      expect(described_class.find_orphans([])).to be_empty
    end
  end

  describe ".sweep" do
    let(:logger) { instance_double(Logger, info: nil, debug: nil) }

    it "kills every detected orphan via the injected killer" do
      processes = [
        { pid: 100, ppid: 1, command: "Chrome --user-data-dir=/tmp/ferrum_user_data_dir_a" },
        { pid: 200, ppid: 1, command: "Chrome --user-data-dir=/tmp/ferrum_user_data_dir_b" }
      ]
      killed = []
      killer = ->(pid, _log) { killed << pid }

      described_class.sweep(logger: logger, lister: -> { processes }, killer: killer)

      expect(killed).to contain_exactly(100, 200)
    end

    it "does nothing when no orphans are present" do
      killed = []
      killer = ->(pid, _log) { killed << pid }

      described_class.sweep(logger: logger, lister: -> { [] }, killer: killer)

      expect(killed).to be_empty
    end

    it "is a no-op on Windows" do
      stub_const("RUBY_PLATFORM", "x86_64-mingw32")
      lister_called = false
      lister = lambda do
        lister_called = true
        []
      end

      described_class.sweep(logger: logger, lister: lister, killer: ->(_pid, _log) {})

      expect(lister_called).to be false
    end
  end

  describe ".kill_process" do
    let(:logger) { instance_double(Logger, info: nil, debug: nil) }

    it "swallows ESRCH when the process is already gone" do
      allow(Process).to receive(:kill).and_raise(Errno::ESRCH)
      expect { described_class.kill_process(999, logger) }.not_to raise_error
    end

    it "swallows EPERM when we lack permission" do
      allow(Process).to receive(:kill).and_raise(Errno::EPERM)
      expect { described_class.kill_process(999, logger) }.not_to raise_error
    end
  end
end
