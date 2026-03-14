# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::TemplateRenderer do
  let(:context) do
    {last_user_message: "Hello!", system_message: "You are helpful.", model: "gpt-4"}
  end

  describe ".render" do
    it "substitutes {{last_user_message}}" do
      result = described_class.render("Reply to: {{last_user_message}}", context)
      expect(result).to eq("Reply to: Hello!")
    end

    it "substitutes {{system_message}}" do
      result = described_class.render("System: {{system_message}}", context)
      expect(result).to eq("System: You are helpful.")
    end

    it "substitutes {{model}}" do
      result = described_class.render("Using {{model}}", context)
      expect(result).to eq("Using gpt-4")
    end

    it "substitutes multiple variables in one template" do
      result = described_class.render("{{model}}: {{last_user_message}}", context)
      expect(result).to eq("gpt-4: Hello!")
    end

    it "leaves unrecognized variables as-is" do
      result = described_class.render("{{unknown}}", context)
      expect(result).to eq("{{unknown}}")
    end

    it "returns the template unchanged when context values are nil" do
      ctx = {last_user_message: nil, system_message: nil, model: nil}
      result = described_class.render("Reply to: {{last_user_message}}", ctx)
      expect(result).to eq("Reply to: ")
    end
  end
end
