# frozen_string_literal: true

require "spec_helper"
require "browserctl/error/codes"

# Drift guard: the table in docs/reference/errors.md must list exactly the codes
# in Browserctl::Error::Codes::ALL. Any new code added to the enum (or removed
# from it) without a matching doc edit will fail this spec.
ERRORS_MD_PATH = File.expand_path("../../docs/reference/errors.md", __dir__)

RSpec.describe "docs/reference/errors.md" do
  def code_table_rows
    contents = File.read(ERRORS_MD_PATH)
    # Locate the "Code reference" section table.
    section = contents[/## Code reference.*?(?=\n## |\z)/m]
    raise "Code reference section not found in #{ERRORS_MD_PATH}" unless section

    section.each_line.select { |line| line.start_with?("|") }
  end

  def codes_in_table
    rows = code_table_rows
    # Drop the header row and the alignment row (the two rows whose first cell
    # is "Code" or contains only dashes/whitespace).
    data_rows = rows.reject do |line|
      cells = line.split("|").map(&:strip)
      first = cells[1].to_s
      first == "Code" || first.match?(/\A-+\z/)
    end
    data_rows.map do |line|
      cell = line.split("|")[1].to_s.strip
      cell.delete("`")
    end
  end

  it "lists exactly the codes in Browserctl::Error::Codes::ALL" do
    documented = codes_in_table.sort
    canonical  = Browserctl::Error::Codes::ALL.sort
    message = "errors.md table drifted from Codes::ALL.\n" \
              "in doc only:  #{(documented - canonical).inspect}\n" \
              "in code only: #{(canonical - documented).inspect}"
    expect(documented).to eq(canonical), message
  end
end
