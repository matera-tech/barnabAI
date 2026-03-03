# frozen_string_literal: true

module Notifications
  class Registry
    TYPES_DIR = Rails.root.join("app/services/notifications/types")

    def self.all
      eager_load_types!
      BaseNotification.descendants.select { |k| k.notification_type.present? }
    end

    def self.grouped_by_category
      all.group_by(&:category)
    end

    def self.eager_load_types!
      return if @loaded

      Rails.autoloaders.main.eager_load_dir(TYPES_DIR.to_s) if TYPES_DIR.exist?
      @loaded = true
    end
  end
end
