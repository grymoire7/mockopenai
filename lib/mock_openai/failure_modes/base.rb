# frozen_string_literal: true

module MockOpenAI
  module FailureModes
    REGISTRY = {} # populated by each subclass on require

    def self.apply(mode, request:, response:)
      key = mode.to_s
      klass = REGISTRY.fetch(key) { raise ArgumentError, "Unknown failure mode: #{mode}" }
      klass.new.apply(request: request, response: response)
    end

    class Base
      def apply(request:, response:)
        raise NotImplementedError, "#{self.class} must implement #apply"
      end
    end
  end
end
