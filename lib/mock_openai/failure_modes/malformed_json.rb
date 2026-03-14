# frozen_string_literal: true

module MockOpenAI
  module FailureModes
    class MalformedJson < Base
      def apply(request:, response:)
        [200, {"Content-Type" => "application/json"}, ['{ "choices": [ ']]
      end
    end

    REGISTRY["malformed_json"] = MalformedJson
  end
end
