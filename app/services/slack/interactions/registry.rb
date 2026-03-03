# frozen_string_literal: true

module Slack
  module Interactions
    class Registry
      HANDLERS_DIR = Rails.root.join("app/services/slack/interactions/handlers")

      def self.all
        eager_load_handlers!
        BaseHandler.descendants
      end

      def self.eager_load_handlers!
        return if @loaded

        Rails.autoloaders.main.eager_load_dir(HANDLERS_DIR.to_s) if HANDLERS_DIR.exist?
        @loaded = true
      end
    end
  end
end
