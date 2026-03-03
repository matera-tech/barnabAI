# frozen_string_literal: true

class ProcessGithubWebhookJob < ApplicationJob
  queue_as :default

  def perform(event_type:, delivery_id:, payload:)
    Rails.logger.info("Processing GitHub webhook: event=#{event_type}, delivery=#{delivery_id}")

    case event_type
    when 'pull_request'
      handle_pull_request_event(payload)
    end

    Notifications::Dispatcher.dispatch(event_type, payload)
  end

  private

  def handle_pull_request_event(payload)
    action = payload['action']
    pr_data = payload['pull_request']
    repo_data = payload['repository']
    repository_full_name = repo_data['full_name']

    pull_request = create_or_update_pull_request(repository_full_name, pr_data)
    return unless pull_request

    if action == 'closed' && pr_data['merged']
      sender_login = payload.dig('sender', 'login')
      UpdatePullRequestTeamsJob.perform_later(repository_full_name, pull_request.number, sender_login: sender_login)
    end
  end

  def create_or_update_pull_request(repository_full_name, pr_data)
    pull_request = PullRequest.find_or_initialize_by(
      repository_full_name: repository_full_name,
      number: pr_data['number']
    )

    pull_request.apply_pr_data(pr_data)

    if pull_request.save
      Rails.logger.info("Saved PR ##{pull_request.number} for #{repository_full_name}")
      pull_request
    else
      Rails.logger.error("Failed to save PR: #{pull_request.errors.full_messages.join(', ')}")
      nil
    end
  end
end
