# frozen_string_literal: true

require "spec_helper"
require "browserctl/flows/stdlib/totp_2fa"

RSpec.describe "stdlib flow: totp_2fa" do
  # RFC 6238 Appendix B test vectors. Secret is the ASCII bytes
  # "12345678901234567890" → base32 below.
  let(:rfc_6238_secret) { "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ" }

  describe Browserctl::Flows::TOTP do
    it "matches RFC 6238 test vectors at digits: 8" do
      vectors = {
        59 => "94287082",
        1_111_111_109 => "07081804",
        1_111_111_111 => "14050471",
        1_234_567_890 => "89005924",
        2_000_000_000 => "69279037"
      }
      vectors.each do |t, expected|
        got = described_class.generate(rfc_6238_secret, at: Time.at(t), digits: 8)
        expect(got).to eq(expected), "expected #{expected} at t=#{t}, got #{got}"
      end
    end

    it "returns the right number of digits" do
      code = described_class.generate(rfc_6238_secret, at: Time.at(59), digits: 6)
      expect(code).to match(/\A\d{6}\z/)
    end

    it "ignores spaces and lowercase in the base32 secret" do
      a = described_class.generate(rfc_6238_secret, at: Time.at(59))
      b = described_class.generate("gezd gnbv gy3t qojq gezd gnbv gy3t qojq", at: Time.at(59))
      expect(a).to eq(b)
    end
  end

  describe "the registered flow" do
    let(:page) { instance_double(Browserctl::PageProxy) }

    before do
      Browserctl.flow_registry_reset!
      load File.expand_path("../../../../lib/browserctl/flows/stdlib/totp_2fa.rb", __dir__)
    end
    after { Browserctl.flow_registry_reset! }

    it "registers under the name 'totp_2fa'" do
      flow = Browserctl.lookup_flow("totp_2fa")
      expect(flow).to be_a(Browserctl::Flow)
      expect(flow.version_string).to eq("1.0.0")
      expect(flow.min_browserctl_version).to eq("0.11.0")
    end

    it "fills the selector with the code computed from the secret" do
      flow = Browserctl.lookup_flow("totp_2fa")
      allow(Time).to receive(:now).and_return(Time.at(59))
      expect(page).to receive(:fill).with("input#totp", "287082")

      flow.run(page: page, secret: rfc_6238_secret, selector: "input#totp")
    end

    it "raises a precondition error when no page proxy is given" do
      flow = Browserctl.lookup_flow("totp_2fa")

      expect { flow.run(secret: rfc_6238_secret, selector: "input#totp") }
        .to raise_error(Browserctl::FlowPreconditionError, /page proxy/)
    end

    it "requires the secret param" do
      flow = Browserctl.lookup_flow("totp_2fa")

      expect { flow.run(page: page, selector: "input#totp") }
        .to raise_error(Browserctl::FlowParamError, /secret/)
    end
  end
end
