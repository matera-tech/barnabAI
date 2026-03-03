# frozen_string_literal: true

module Slack
  module Interactions
    module Handlers
      class NotificationToggleHandler < BaseHandler
        def self.match?(action, payload)
          action_id = action["action_id"]
          action_id&.start_with?("notif_") && action_id&.end_with?("_toggle")
        end

        def self.call(user:, action:, payload:)
          update_preferences(user, action)
          publish_home_tab(user)
        end

        def self.update_preferences(user, action)
          selected_types = (action["selected_options"] || []).map { |o| o["value"] }
          category_slug = action["action_id"].sub(/\Anotif_/, "").sub(/_toggle\z/, "")

          all_types_in_category = Notifications::Registry.grouped_by_category.detect { |cat, _|
            cat.parameterize == category_slug
          }&.last || []

          all_types_in_category.each do |klass|
            pref = user.notification_preferences.find_or_initialize_by(
              notification_type: klass.notification_type
            )
            pref.enabled = selected_types.include?(klass.notification_type)
            pref.save!
          end
        end

        def self.publish_home_tab(user)
          view = Slack::HomeTabBuilder.new(user).build
          Slack::Client.views_publish(user_id: user.slack_user_id, view: view)
        end
      end
    end
  end
end
