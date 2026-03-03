# frozen_string_literal: true

module Slack
  class HomeTabBuilder
    def self.build_not_connected(slack_user_id)
      oauth_url = Rails.application.routes.url_helpers.github_oauth_authorize_url(
        slack_user_id: slack_user_id,
        host: ENV.fetch("APP_HOST", "localhost:3000"),
        protocol: ENV.fetch("APP_PROTOCOL", "http")
      )

      blocks = [
        { type: "header", text: { type: "plain_text", text: "Welcome to BarnabAI!" } },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: ":wave: *Get started by connecting your GitHub account.*\n" \
                  "This lets me send you notifications and help you with PRs, reviews, and more."
          },
          accessory: {
            type: "button",
            text: { type: "plain_text", text: "Connect GitHub" },
            style: "primary",
            url: oauth_url,
            action_id: "connect_github"
          }
        }
      ]

      Notifications::Registry.grouped_by_category.each do |category, types|
        type_list = types.map { |t| "~#{t.notification_type.humanize}~ — _#{t.description}_" }.join("\n")
        blocks += [
          { type: "divider" },
          { type: "section", text: { type: "mrkdwn", text: "*#{category}*" } },
          { type: "context", elements: [{ type: "mrkdwn", text: type_list }] }
        ]
      end

      { type: "home", blocks: blocks }
    end

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

    def github_connected?
      @github_connected ||= @user.primary_github_token.present?
    end

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
        oauth_url = Rails.application.routes.url_helpers.github_oauth_authorize_url(
          slack_user_id: @user.slack_user_id,
          host: ENV.fetch("APP_HOST", "localhost:3000"),
          protocol: ENV.fetch("APP_PROTOCOL", "http")
        )

        blocks += [
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: ":warning: *GitHub account not connected*\nConnect your GitHub account to enable notifications."
            },
            accessory: {
              type: "button",
              text: { type: "plain_text", text: "Connect GitHub" },
              style: "primary",
              url: oauth_url,
              action_id: "connect_github"
            }
          }
        ]
      end

      blocks
    end

    def category_blocks(category, types)
      return disabled_category_blocks(category, types) unless github_connected?

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

    def disabled_category_blocks(category, types)
      type_list = types.map { |t| "~#{t.notification_type.humanize}~ — _#{t.description}_" }.join("\n")
      [
        { type: "divider" },
        { type: "section", text: { type: "mrkdwn", text: "*#{category}*" } },
        { type: "context", elements: [{ type: "mrkdwn", text: type_list }] }
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
