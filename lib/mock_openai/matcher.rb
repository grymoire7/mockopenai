# frozen_string_literal: true

module MockOpenAI
  class Matcher
    def self.match(rules, last_user_message)
      rules.each do |rule|
        return rule if matches?(rule["match"], last_user_message)
      end
      nil
    end

    def self.matches?(pattern, text)
      return false if pattern.nil?

      # 1. Try regex match if pattern looks like a regex
      if regex_like?(pattern)
        begin
          return true if Regexp.new(pattern).match?(text)
        rescue RegexpError
          puts "[MockOpenAI] Warning: invalid regex '#{pattern}', falling back to substring match"
          # Fall through to substring match
        end
      end

      # 2. Exact match
      return true if pattern == text

      # 3. Substring match
      text.include?(pattern)
    end

    def self.regex_like?(pattern)
      pattern.start_with?("^") ||
        pattern.end_with?("$") ||
        pattern.include?(".*") ||
        pattern.include?("(") ||
        pattern.include?("[")
    end
  end
end
