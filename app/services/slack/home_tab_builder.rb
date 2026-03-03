# frozen_string_literal: true

module Slack
  class HomeTabBuilder
    def initialize(user)
      @user = user
      @preferences = user.notification_preferences.index_by(&:notification_type)
    end

    def build
      blocks = header_blocks
      Notifications::Registry.grouped_by_category.each do |category, types|
        blocks += category_blocks(category, types)
      end
      { type: "home", blocks: blocks }
    end

    private

    def header_blocks
      blocks = [
        { type: "header", text: { type: "plain_text", text: "Notification Settings" } }
      ]

      github_token = @user.primary_github_token
      if github_token
        blocks << {
          type: "context",
          elements: [
            { type: "mrkdwn", text: ":white_check_mark: Connected to GitHub as *@#{github_token.github_username}*" }
          ]
        }
      else
        blocks << {
          type: "context",
          elements: [
            { type: "mrkdwn", text: ":warning: GitHub account not connected. DM me to get started." }
          ]
        }
      end

      blocks
    end

    def category_blocks(category, types)
      options = types.map { |t| checkbox_option(t) }
      initial = types.select { |t| enabled?(t) }.map { |t| checkbox_option(t) }

      action_block = { type: "checkboxes", action_id: "notif_#{category.parameterize}_toggle", options: options }
      action_block[:initial_options] = initial if initial.any?

      [
        { type: "divider" },
        { type: "section", text: { type: "mrkdwn", text: "*#{category}*" } },
        { type: "actions", block_id: "notif_#{category.parameterize}", elements: [action_block] }
      ]
    end

    def checkbox_option(type)
      {
        text: { type: "mrkdwn", text: "*#{type.notification_type.humanize}*" },
        description: { type: "plain_text", text: type.description },
        value: type.notification_type
      }
    end

    def enabled?(type)
      pref = @preferences[type.notification_type]
      pref ? pref.enabled : type.default_enabled
    end
  end
end
