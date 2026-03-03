# frozen_string_literal: true

module Slack
  module Interactions
    class Dispatcher
      def self.dispatch(user:, action:, payload:)
        handler = Registry.all.find { |h| h.match?(action, payload) }
        if handler
          handler.call(user: user, action: action, payload: payload)
        else
          Rails.logger.debug("No interactive handler matched action_id=#{action['action_id']}")
        end
      end
    end
  end
end
