# frozen_string_literal: true

module MockOpenAI
  class TemplateRenderer
    VARIABLES = {
      "{{last_user_message}}" => ->(ctx) { ctx[:last_user_message].to_s },
      "{{system_message}}" => ->(ctx) { ctx[:system_message].to_s },
      "{{model}}" => ->(ctx) { ctx[:model].to_s }
    }.freeze

    def self.render(template, context)
      VARIABLES.reduce(template) do |result, (placeholder, extractor)|
        result.gsub(placeholder, extractor.call(context))
      end
    end
  end
end
