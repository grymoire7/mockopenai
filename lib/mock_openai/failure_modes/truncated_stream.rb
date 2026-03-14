# frozen_string_literal: true

module MockOpenAI
  module FailureModes
    class TruncatedStream < Base
      def apply(request:, response:)
        :stream_truncated
      end
    end

    REGISTRY["truncated_stream"] = TruncatedStream
  end
end
