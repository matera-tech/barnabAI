# frozen_string_literal: true

module Slack
  module Interactions
    class BaseHandler
      class << self
        def match?(action, payload)
          raise NotImplementedError
        end

        def call(user:, action:, payload:)
          raise NotImplementedError
        end
      end
    end
  end
end
