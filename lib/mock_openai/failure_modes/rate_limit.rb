# frozen_string_literal: true

module MockOpenAI
  module FailureModes
    class RateLimit < Base
      def apply(request:, response:)
        body = {
          "error" => {
            "type" => "rate_limit_error",
            "message" => "Rate limit exceeded",
            "code" => "rate_limit_exceeded"
          }
        }
        [429, {"Content-Type" => "application/json"}, [body.to_json]]
      end
    end

    REGISTRY["rate_limit"] = RateLimit
  end
end
