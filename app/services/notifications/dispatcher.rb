# frozen_string_literal: true

module Notifications
  class Dispatcher
    def self.dispatch(event_type, payload)
      Registry.all.each do |klass|
        next unless klass.match?(event_type, payload)

        users = klass.recipients(event_type, payload).compact
        users = users.select { |user| enabled_for?(user, klass) }
        next if users.empty?

        DeliverNotificationJob.set(priority: klass.priority).perform_later(
          notification_class_name: klass.name,
          event_type: event_type,
          payload: payload,
          user_ids: users.map(&:id)
        )
      end
    end

    def self.enabled_for?(user, klass)
      pref = user.notification_preferences.find_by(notification_type: klass.notification_type)
      pref ? pref.enabled : klass.default_enabled
    end
  end
end
