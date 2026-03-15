# spec/integration/minitest_integration_spec.rb
# frozen_string_literal: true

require "spec_helper"
require "mock_openai/minitest"

RSpec.describe "Minitest integration" do
  include Rack::Test::Methods

  def app
    MockOpenAI::Router.new
  end

  def post_chat(user_message = "hi")
    body = {
      "model" => "gpt-4",
      "messages" => [{"role" => "user", "content" => user_message}]
    }.to_json
    post "/v1/chat/completions", body, "CONTENT_TYPE" => "application/json"
  end

  # Simulate a Minitest::Test subclass that includes the module.
  # base_class simulates Minitest::Test's no-op lifecycle callbacks.
  let(:base_class) do
    Class.new do
      def before_setup
      end

      def after_teardown
      end
    end
  end

  let(:test_class) do
    klass = base_class
    Class.new(klass) { include MockOpenAI::Minitest }
  end

  let(:test_instance) { test_class.new }

  it "before_setup resets state" do
    MockOpenAI.set_responses([{match: "ping", response: "pong"}])
    expect(MockOpenAI::State.read["rules"].length).to eq(1)

    test_instance.before_setup

    expect(MockOpenAI::State.read["rules"]).to eq([])
  end

  it "after_teardown resets state" do
    MockOpenAI.set_responses([{match: "ping", response: "pong"}])
    expect(MockOpenAI::State.read["rules"].length).to eq(1)

    test_instance.after_teardown

    expect(MockOpenAI::State.read["rules"]).to eq([])
  end

  it "before_setup calls super so parent lifecycle hooks still fire" do
    super_called = false
    base_class.define_method(:before_setup) { super_called = true }

    test_instance.before_setup

    expect(super_called).to be true
  end

  it "after_teardown calls super so parent lifecycle hooks still fire" do
    super_called = false
    base_class.define_method(:after_teardown) { super_called = true }

    test_instance.after_teardown

    expect(super_called).to be true
  end

  it "rules set after before_setup are used for HTTP responses" do
    test_instance.before_setup
    MockOpenAI.set_responses([{match: "ping", response: "pong"}])

    post_chat("ping")

    body = JSON.parse(last_response.body)
    expect(body.dig("choices", 0, "message", "content")).to eq("pong")
  end
end
