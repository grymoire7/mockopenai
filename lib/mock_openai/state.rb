# frozen_string_literal: true

module MockOpenAI
  module State
    def self.write(data)
      # stub
    end

    def self.read
      {"rules" => []}
    end

    def self.reset!
      # stub
    end
  end
end
