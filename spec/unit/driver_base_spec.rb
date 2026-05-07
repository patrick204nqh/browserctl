# frozen_string_literal: true

require "spec_helper"
require "browserctl/driver/base"

RSpec.describe Browserctl::Driver::Base do
  subject(:driver) { described_class.new }

  it "raises NotImplementedError for #create_page" do
    expect { driver.create_page }.to raise_error(NotImplementedError, /create_page/)
  end

  it "raises NotImplementedError for #quit" do
    expect { driver.quit }.to raise_error(NotImplementedError, /quit/)
  end

  it "raises NotImplementedError for #headed?" do
    expect { driver.headed? }.to raise_error(NotImplementedError, /headed\?/)
  end

  it "raises NotImplementedError for #devtools_info" do
    expect { driver.devtools_info(double("page")) }.to raise_error(NotImplementedError, /devtools_info/)
  end

  it "returns false for #supports? any capability" do
    expect(driver.supports?(:devtools)).to be false
    expect(driver.supports?(:anything)).to be false
  end
end
