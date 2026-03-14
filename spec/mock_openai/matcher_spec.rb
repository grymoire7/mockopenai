# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::Matcher do
  let(:rules) do
    [
      {"match" => "Hello", "response" => "Hi!"},
      {"match" => "^Order.*", "response" => "Order shipped."},
      {"match" => "thank", "response" => "You're welcome!"},
      {"match" => ".*", "failure_mode" => "timeout"}
    ]
  end

  describe ".match" do
    it "returns the first rule with an exact match" do
      expect(described_class.match(rules, "Hello")).to eq(rules[0])
    end

    it "returns a rule that regex-matches (anchored start)" do
      expect(described_class.match(rules, "Order status?")).to eq(rules[1])
    end

    it "returns a rule that substring-matches" do
      expect(described_class.match(rules, "Many thanks!")).to eq(rules[2])
    end

    it "returns the catch-all rule when no specific match" do
      expect(described_class.match(rules, "something unrelated")).to eq(rules[3])
    end

    it "returns nil when no rules are defined" do
      expect(described_class.match([], "Hello")).to be_nil
    end

    it "exact match takes precedence over substring match" do
      rules_local = [
        {"match" => "Hello world", "response" => "exact"},
        {"match" => "Hello", "response" => "substring"}
      ]
      expect(described_class.match(rules_local, "Hello world")).to eq(rules_local[0])
    end

    context "when a rule has a malformed regex" do
      it "falls back to substring matching and logs a warning" do
        bad_rules = [{"match" => "^[unclosed", "response" => "ok"}]
        expect do
          result = described_class.match(bad_rules, "^[unclosed")
          expect(result).to eq(bad_rules[0])
        end.to output(/\[MockOpenAI\].*regex/).to_stdout
      end
    end
  end
end
