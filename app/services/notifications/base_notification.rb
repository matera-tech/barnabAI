# frozen_string_literal: true

module Notifications
  class BaseNotification
    class << self
      def notification_type(val = nil)
        @notification_type = val if val
        @notification_type
      end

      def category(val = nil)
        @category = val if val
        @category
      end

      def description(val = nil)
        @description = val if val
        @description
      end

      def default_enabled(val = nil)
        @default_enabled = val unless val.nil?
        instance_variable_defined?(:@default_enabled) ? @default_enabled : false
      end

      # Integer priority for Solid Queue (lower = higher priority).
      # 0 = immediate, 5 = default/informational, 10 = low.
      def priority(val = nil)
        @priority = val if val
        @priority || 5
      end

      def match?(event_type, payload)
        raise NotImplementedError
      end

      def recipients(event_type, payload)
        raise NotImplementedError
      end
    end

    def initialize(event_type, payload)
      @event_type = event_type
      @payload = payload
    end

    # Returns a Slack::MessageBuilder (call .send! to deliver).
    def build_message(user)
      raise NotImplementedError
    end

    protected

    def ai_provider
      @ai_provider ||= AIProviderFactory.create(nil)
    end

    def github_client(user)
      Github::Client.new(user)
    end
  end
end
