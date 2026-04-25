# frozen_string_literal: true

require "spec_helper"
require "browserctl/errors"

RSpec.describe Browserctl::Error do
  it "has a code" do
    err = described_class.new("something broke", code: "generic_error")
    expect(err.code).to eq("generic_error")
    expect(err.message).to eq("something broke")
  end

  it "defaults to its class default_code" do
    err = Browserctl::PageNotFound.new("no page named 'main'")
    expect(err.code).to eq("page_not_found")
    expect(err.message).to eq("no page named 'main'")
  end
end

RSpec.describe Browserctl::SelectorNotFound do
  it "has code selector_not_found" do
    expect(described_class.new("x").code).to eq("selector_not_found")
  end
end

RSpec.describe Browserctl::RefNotFound do
  it "has code ref_not_found" do
    expect(described_class.new("x").code).to eq("ref_not_found")
  end
end

RSpec.describe Browserctl::PathNotAllowed do
  it "has code path_not_allowed" do
    expect(described_class.new("x").code).to eq("path_not_allowed")
  end
end

RSpec.describe Browserctl::DomainNotAllowed do
  it "has code domain_not_allowed" do
    expect(described_class.new("x").code).to eq("domain_not_allowed")
  end
end

RSpec.describe Browserctl::TimeoutError do
  it "has code timeout" do
    expect(described_class.new("x").code).to eq("timeout")
  end
end

RSpec.describe Browserctl::KeyNotFound do
  it "has code key_not_found" do
    expect(described_class.new("x").code).to eq("key_not_found")
  end
end
