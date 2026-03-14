# frozen_string_literal: true

require_relative "../lib/mock_openai"

# Point at a temp file for this demo
MockOpenAI.instance_variable_set(:@config, MockOpenAI::Config.new(state_file: "/tmp/mock_openai_demo.json"))

# Set deterministic responses
MockOpenAI.set_responses([
  {match: "hello", response: "Hi there!"},
  {match: "^Order", response: "Your order is on its way."},
  {match: ".*", response: "I don't understand that."}
])

state = MockOpenAI::State.read
puts "Rules written: #{state["rules"].length}"
state["rules"].each { |r| puts "  #{r["match"].ljust(12)} => #{r["response"]}" }

# Set a failure mode
MockOpenAI.set_failure_mode(:rate_limit)
puts "\nCurrent failure mode: #{MockOpenAI.current_failure_mode}"

# Reset
MockOpenAI.reset!
puts "After reset — rules: #{MockOpenAI::State.read["rules"].length}, mode: #{MockOpenAI.current_failure_mode.inspect}"
