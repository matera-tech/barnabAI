# frozen_string_literal: true

module Notifications
  module Types
    class CiFailureNotification < BaseNotification
      notification_type "ci_failure"
      category "CI & Checks"
      description "When checks fail on your pull requests"
      default_enabled true
      priority 5

      def self.match?(event_type, payload)
        event_type == "check_suite" &&
          payload.dig("action") == "completed" &&
          payload.dig("check_suite", "conclusion") == "failure" &&
          payload.dig("check_suite", "pull_requests")&.any?
      end

      def self.recipients(event_type, payload)
        repo = payload.dig("repository", "full_name")
        pr_numbers = payload.dig("check_suite", "pull_requests")&.map { |pr| pr["number"] } || []

        pull_requests = PullRequest.where(repository_full_name: repo, number: pr_numbers)
        github_logins = pull_requests.flat_map { |pr| [pr.author, *pr.assignees] }.compact.uniq

        User.where(slack_user_id: UserMapping.where(github_username: github_logins).select(:slack_user_id))
      end

      def build_message(user)
        check_runs = Github::CheckRunsFetcher.new(user).call_by_sha(repo_full_name, head_sha)
        failed_runs = check_runs.select { |r| r[:conclusion] == "FAILURE" }

        pr_numbers = @payload.dig("check_suite", "pull_requests")&.map { |pr| pr["number"] } || []
        prs = PullRequest.where(repository_full_name: repo_full_name, number: pr_numbers)

        analysis = ai_provider.chat_completion(
          build_ci_analysis_prompt(failed_runs, prs),
          response_format: :text
        )

        pr_links = prs.map { |pr| "<https://github.com/#{repo_full_name}/pull/#{pr.number}|##{pr.number} #{pr.title}>" }

        Slack::MessageBuilder.new(text: "CI checks failed on #{repo_full_name}")
          .add_header_block(":x: CI Checks Failed")
          .add_section_block("*Repository:* #{repo_full_name}\n*Pull Requests:* #{pr_links.join(', ')}")
          .add_divider
          .add_section_block(analysis)
          .add_context_block("#{failed_runs.size} check(s) failed · <https://github.com/#{repo_full_name}/commit/#{head_sha}/checks|View all checks>")
      end

      private

      def repo_full_name = @payload.dig("repository", "full_name")
      def head_sha = @payload.dig("check_suite", "head_sha")

      def build_ci_analysis_prompt(failed_runs, prs)
        pr_context = prs.map { |pr| "PR ##{pr.number}: #{pr.title}" }.join("\n")
        runs_summary = failed_runs.map { |r|
          summary = "- *#{r[:name]}* (#{r[:app]}): #{r[:conclusion]}"
          if r[:annotations]&.any?
            annotations = r[:annotations].map { |a| "  #{a[:path]}:#{a[:start_line]} — #{a[:message]}" }.join("\n")
            summary += "\n#{annotations}"
          end
          summary
        }.join("\n")

        [
          { role: "system", content: "You analyze CI failures for developers. Be concise and actionable. Output Slack mrkdwn. Do not use headers." },
          { role: "user", content: "These checks failed in #{repo_full_name}:\n\n#{runs_summary}\n\nPull requests affected:\n#{pr_context}\n\nSummarize what failed, likely root cause, and suggested next steps." }
        ]
      end
    end
  end
end
