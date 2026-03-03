# frozen_string_literal: true

class DeliverNotificationJob < ApplicationJob
  queue_as :default

  def perform(notification_class_name:, event_type:, payload:, user_ids:)
    klass = notification_class_name.constantize
    users = User.where(id: user_ids).to_a
    return if users.empty?

    api_user = users.find { |u| u.primary_github_token.present? }
    return unless api_user

    notification = klass.new(event_type, payload)
    message = notification.build_message(api_user)

    users.each do |user|
      message.send!(channel: user.slack_user_id)
    rescue => e
      Rails.logger.error("Notification #{klass.notification_type} delivery failed for user #{user.id}: #{e.message}")
    end
  end
end
