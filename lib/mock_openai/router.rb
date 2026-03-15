# frozen_string_literal: true

module MockOpenAI
  class Router
    NOT_FOUND_BODY = {
      "error" => {"type" => "invalid_request_error", "message" => "Not found"}
    }.to_json.freeze

    def call(env)
      request = Rack::Request.new(env)

      case [request.request_method, request.path_info]
      in ["POST", "/v1/chat/completions"]
        Handlers::ChatCompletions.new.call(env)
      in ["POST", "/v1/messages"]
        Handlers::Messages.new.call(env)
      else
        [404, {"Content-Type" => "application/json"}, [NOT_FOUND_BODY]]
      end
    end
  end
end
