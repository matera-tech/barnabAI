# frozen_string_literal: true

module Notifications
  module Types
    class ProductionDeploymentNotification < BaseNotification
      notification_type "production_deployment"
      category "Deployments"
      description "When a MEP containing your work is merged to production"
      default_enabled true

      MEP_TITLE_PATTERN = /\AMEP \d{2}-\d{2}-\d{4}-\d{2}H\z/

      def self.match?(event_type, payload)
        event_type == "pull_request" &&
          payload["action"] == "closed" &&
          payload.dig("pull_request", "merged") == true &&
          payload.dig("pull_request", "title")&.match?(MEP_TITLE_PATTERN)
      end

      def self.recipients(event_type, payload)
        assignee_logins = Array(payload.dig("pull_request", "assignees"))
          .map { |a| a["login"] }.compact

        User.where(slack_user_id: UserMapping.where(github_username: assignee_logins).select(:slack_user_id))
      end

      def build_message(_user)
        body_text = markdown_to_slack_mrkdwn(@payload.dig("pull_request", "body").to_s)

        Slack::MessageBuilder.new(text: "#{mep_title} deployed to production")
          .add_section_block(":rocket: *<#{mep_url}|#{mep_title}>* has been merged to *#{base_branch}*")
          .add_divider
          .add_section_block(body_text.presence || "_No description provided._")
      end

      private

      def mep_title = @payload.dig("pull_request", "title")
      def mep_url = @payload.dig("pull_request", "html_url")
      def base_branch = @payload.dig("pull_request", "base", "ref")

      def markdown_to_slack_mrkdwn(text)
        repo = @payload.dig("repository", "full_name")

        text
          .gsub(/^###?\s+(.+)$/, '*\1*')
          .gsub(/\[([^\]]+)\]\(([^)]+)\)/, '<\2|\1>')
          .gsub(/\*\*(.+?)\*\*/, '*\1*')
          .gsub(/#(\d+)/) { "<https://github.com/#{repo}/pull/#{$1}|##{$1}>" }
      end
    end
  end
end
