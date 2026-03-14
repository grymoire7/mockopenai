# frozen_string_literal: true

require_relative "../lib/mock_openai"
require "rack/test"
require "json"
require "stringio"

# Use a dedicated state file and reset it at startup
MockOpenAI.instance_variable_set(:@config, MockOpenAI::Config.new(state_file: "/tmp/mock_openai_demo_http.json"))
MockOpenAI.reset!

app = MockOpenAI::Router.new
session = Rack::Test::Session.new(Rack::MockSession.new(app))

# Suppress handler log lines ([MockOpenAI] POST ...) during HTTP calls
def silence
  old = $stdout
  $stdout = StringIO.new
  yield
ensure
  $stdout = old
end

def post_chat(session, message, model: "gpt-4")
  body = {"model" => model, "messages" => [{"role" => "user", "content" => message}]}.to_json
  silence { session.post("/v1/chat/completions", body, "CONTENT_TYPE" => "application/json") }
  JSON.parse(session.last_response.body)
end

puts "=== Default response (no rules) ==="
resp = post_chat(session, "anything")
puts "Status: #{session.last_response.status}"
puts "Reply:  #{resp.dig("choices", 0, "message", "content")}"
puts

puts "=== Pattern-matched responses ==="
MockOpenAI.set_responses([
  {match: "hello", response: "Hey! How can I help?"},
  {match: "^summarize", template: "Summary of: {{last_user_message}}"},
  {match: ".*", response: "Fallback answer."}
])

["hello there", "summarize this document please", "something else entirely"].each do |msg|
  resp = post_chat(session, msg)
  puts "  #{msg.ljust(32)} => #{resp.dig("choices", 0, "message", "content")}"
end
puts

puts "=== Failure modes ==="
silence { MockOpenAI.set_failure_mode(:rate_limit) }
silence { session.post("/v1/chat/completions", '{"model":"gpt-4","messages":[{"role":"user","content":"hi"}]}', "CONTENT_TYPE" => "application/json") }
puts "rate_limit     → HTTP #{session.last_response.status}  #{JSON.parse(session.last_response.body).dig("error", "code")}"

MockOpenAI.set_failure_mode(:internal_error)
silence { session.post("/v1/chat/completions", '{"model":"gpt-4","messages":[{"role":"user","content":"hi"}]}', "CONTENT_TYPE" => "application/json") }
puts "internal_error → HTTP #{session.last_response.status}"

MockOpenAI.set_failure_mode(:malformed_json)
silence { session.post("/v1/chat/completions", '{"model":"gpt-4","messages":[{"role":"user","content":"hi"}]}', "CONTENT_TYPE" => "application/json") }
valid = begin
  JSON.parse(session.last_response.body)
rescue
  nil
end
puts "malformed_json → HTTP #{session.last_response.status}  valid JSON? #{valid ? "yes" : "no"}"
puts

MockOpenAI.reset!

puts "=== Error handling ==="
silence { session.post("/v1/chat/completions", "not json at all", "CONTENT_TYPE" => "application/json") }
err = JSON.parse(session.last_response.body)
puts "Bad JSON body  → HTTP #{session.last_response.status}  #{err.dig("error", "type")}"

silence { session.get("/v1/unknown") }
puts "Unknown route  → HTTP #{session.last_response.status}"
