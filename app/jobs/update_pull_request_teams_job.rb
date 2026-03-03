# frozen_string_literal: true

class UpdatePullRequestTeamsJob < ApplicationJob
  queue_as :default

  def perform(repository_full_name, pr_number, sender_login: nil)
    pull_request = PullRequest.find_by(
      repository_full_name: repository_full_name,
      number: pr_number
    )

    user = find_user_with_repo_access(sender_login, pull_request)
    unless user
      Rails.logger.warn('No user with GitHub token found, skipping UpdatePullRequestTeamsJob')
      return
    end

    pull_request ||= PullRequest.new(
      repository_full_name: repository_full_name,
      number: pr_number
    )

    github_service = Github::Client.new(user)

    if pull_request.new_record?
      github_pr = github_service.get_pull_request(repository_full_name, pr_number)
      return unless github_pr

      pull_request.apply_pr_data(github_pr)
    end

    files = github_service.get_files(repository_full_name, pr_number)
    return unless files&.any?

    matcher = Github::CodeOwnersMatcher.new(github_service, repository_full_name)
    pull_request.impacted_teams = matcher.determine_impacted_teams(files)
    pull_request.save!
  rescue StandardError => e
    Rails.logger.error("Failed to update PR teams for #{repository_full_name}/#{pr_number}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end

  private

  def find_user_with_repo_access(sender_login, pull_request)
    logins = [sender_login]
    logins.concat([pull_request.author, *pull_request.assignees]) if pull_request
    logins = logins.compact.uniq

    if logins.any?
      users_by_login = User.joins(:github_tokens)
                           .where(github_tokens: { github_username: logins })
                           .select("users.*, github_tokens.github_username AS token_login")
                           .index_by(&:token_login)

      logins.each do |login|
        return users_by_login[login] if users_by_login[login]
      end
    end

    User.joins(:github_tokens).order(:created_at).first
  end
end
