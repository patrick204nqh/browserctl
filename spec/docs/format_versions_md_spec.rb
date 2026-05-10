# frozen_string_literal: true

require "spec_helper"
require "browserctl"
require "browserctl/state/bundle"
require "browserctl/recording"
require "browserctl/workflow"

# Drift guard: the "Tracked formats" table in docs/reference/format-versions.md
# must agree with the constants in lib/. If a format gets bumped in code without
# the doc being updated (or vice versa), this spec fails.
FORMAT_VERSIONS_MD_PATH = File.expand_path("../../docs/reference/format-versions.md", __dir__)

# Map the human-readable Format column to the canonical integer from code.
FORMAT_VERSIONS_EXPECTED = {
  "State bundle" => Browserctl::State::Bundle::BUNDLE_FORMAT_VERSION,
  "Recording log" => Browserctl::Recording::RECORDING_FORMAT_VERSION,
  "Workflow file" => Browserctl::WORKFLOW_FORMAT_VERSION
}.freeze

RSpec.describe "docs/reference/format-versions.md" do
  def tracked_formats_section
    contents = File.read(FORMAT_VERSIONS_MD_PATH)
    section = contents[/## Tracked formats.*?(?=\n## |\z)/m]
    raise "Tracked formats section not found in #{FORMAT_VERSIONS_MD_PATH}" unless section

    section
  end

  # Returns { "State bundle" => 1, "Recording log" => 1, ... } parsed from the
  # markdown table. Strips backticks; coerces version cell to Integer.
  def documented_versions
    rows = tracked_formats_section.each_line.select { |line| line.start_with?("|") }
    data_rows = rows.reject do |line|
      first = line.split("|")[1].to_s.strip
      first == "Format" || first.match?(/\A-+\z/)
    end

    data_rows.each_with_object({}) do |line, acc|
      cells = line.split("|").map(&:strip)
      format_name = cells[1]
      version_cell = cells[3].to_s.delete("`").strip
      acc[format_name] = Integer(version_cell)
    end
  end

  it "lists every tracked format with its current version" do
    documented = documented_versions
    expect(documented.keys).to match_array(FORMAT_VERSIONS_EXPECTED.keys),
                               "format-versions.md table rows drifted from FORMAT_VERSIONS_EXPECTED"
  end

  FORMAT_VERSIONS_EXPECTED.each do |format_name, expected_version|
    it "documents #{format_name} at the current source-of-truth version" do
      documented = documented_versions[format_name]
      expect(documented).to eq(expected_version),
                            "format-versions.md says #{format_name} is at v#{documented.inspect}, " \
                            "but the constant says v#{expected_version}"
    end
  end
end
