# frozen_string_literal: true

module MockOpenAI
  module FailureModes
    class InternalError < Base
      def apply(request:, response:)
        body = {
          "error" => {
            "type" => "server_error",
            "message" => "Internal server error"
          }
        }
        [500, {"Content-Type" => "application/json"}, [body.to_json]]
      end
    end

    REGISTRY["internal_error"] = InternalError
  end
end
