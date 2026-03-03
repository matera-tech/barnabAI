# frozen_string_literal: true

class NotificationPreference < ApplicationRecord
  belongs_to :user

  validates :notification_type, presence: true
  validates :notification_type, uniqueness: { scope: :user_id }
end
