# frozen_string_literal: true

module MockOpenAI
  module FailureModes
    class Timeout < Base
      def apply(request:, response:)
        :timeout
      end
    end

    REGISTRY["timeout"] = Timeout
  end
end
