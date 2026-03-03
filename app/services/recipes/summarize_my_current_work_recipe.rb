# frozen_string_literal: true

class Recipes::SummarizeMyCurrentWorkRecipe < Recipes::BaseRecipe
  function_code "sys_summarize_my_current_work"
  function_description "Provides the user with a clear list of pull requests on which they are either owner, assigned or requested review. " \
                       "User can optionally specify filters. Results are directly sent to the user without further processing."
  function_parameters({
    type: "object",
    properties: {
      repository: {
        type: "array",
        items: { type: "string" },
        description: "Filter PRs by repository or repositories (format: owner/repo-name). Can be a single repository or multiple repositories. Defaults to all repositories the user has access to."
      },
      label: {
        type: "string",
        description: "Filter PRs by label (optional)."
      },
      created: {
        type: "string",
        description: "Filter by creation date using ISO 8601 format and qualifiers (e.g., '>2023-01-01', '2023-01-01..2023-12-31')."
      },
      updated: {
        type: "string",
        description: "Filter by last updated date using ISO 8601 format and qualifiers (e.g., '>2023-01-01', '2023-01-01..2023-12-31'). Include if user specifically mentions recency or staleness."
      },
      sort: {
        type: "string",
        enum: %w[created updated comments long-running],
        description: "The field to sort the results by. Default: updated"
      },
      order: {
        type: "string",
        enum: %w[desc asc],
        description: "The direction of the sort. Default: asc"
      }
    },
    required: []
  })

  def execute(filters = {})
    filters = (filters || {}).symbolize_keys
    sort = filters.delete(:sort) || "updated"
    order = filters.delete(:order) || "asc"
    search_options = { sort: sort, order: order }

    filter_query = Github::QueryBuilder.to_query(filters)

    prs_owned = github_client.search_pull_requests(
      Github::QueryBuilder.new.where(filter_query).where("is:pr is:open author:@me").build,
      **search_options
    )
    prs_assigned = github_client.search_pull_requests(
      Github::QueryBuilder.new.where(filter_query).where("is:pr is:open assignee:@me").not("author:@me").build,
      **search_options
    )
    prs_review_requested = github_client.search_pull_requests(
      Github::QueryBuilder.new.where(filter_query).where("is:pr is:open review-requested:@me").not("author:@me").not("assignee:@me").build,
      **search_options
    )

    all_prs = prs_owned + prs_assigned + prs_review_requested
    if all_prs.empty?
      Slack::MessageBuilder.new.add_context_block("Nothing to show here :sparkles:")
        .send!(channel: channel_id, thread_ts: context.thread_ts)
      return
    end

    if in_thread?
      send_consolidated(prs_owned, prs_assigned, prs_review_requested)
    else
      send_per_pr(prs_owned, prs_assigned, prs_review_requested)
    end

    nil
  end

  private

  MAX_PER_SECTION = 15

  def send_per_pr(prs_owned, prs_assigned, prs_review_requested)
    send_pr_messages(prs_owned)
    send_pr_messages(prs_assigned)
    send_pr_messages(prs_review_requested)
  end

  def send_pr_messages(pull_requests)
    pull_requests.first(MAX_PER_SECTION).each do |pr|
      build_pr_message(pr).send!(channel: channel_id)
    end
    return unless pull_requests.count > MAX_PER_SECTION

    Slack::MessageBuilder.new
      .add_context_block(":pencil: Only showing #{MAX_PER_SECTION}/#{pull_requests.count} results.")
      .send!(channel: channel_id)
  end

  def send_consolidated(prs_owned, prs_assigned, prs_review_requested)
    message = Slack::MessageBuilder.new

    append_section(message, prs_owned, ":writing_hand: Authored")
    append_section(message, prs_assigned, ":bust_in_silhouette: Assigned")
    append_section(message, prs_review_requested, ":eyes: Review requested")

    message.send!(channel: channel_id, thread_ts: context.thread_ts)
  end

  def append_section(message, pull_requests, heading)
    return if pull_requests.empty?

    message.add_header_block(heading)
    pull_requests.first(MAX_PER_SECTION).each do |pr|
      append_pr_blocks(message, pr)
    end
    if pull_requests.count > MAX_PER_SECTION
      message.add_context_block(":pencil: Only showing #{MAX_PER_SECTION}/#{pull_requests.count} results.")
    end
  end

  def build_pr_message(pr)
    message = Slack::MessageBuilder.new(text: "PR ##{pr.number}: #{pr.title}")
    append_pr_blocks(message, pr)
    message
  end

  def append_pr_blocks(message, pr)
    opened_since = ActionController::Base.helpers.distance_of_time_in_words(Time.current, pr.created_at)
    stale_since = ActionController::Base.helpers.distance_of_time_in_words(Time.current, pr.updated_at)

    message
      .add_section_block("*(##{pr.number}) #{Slack::Messages::Formatting.url_link(pr.title, pr.html_url)}*")
      .add_context_block(
        ":github: Repo: *#{pr.base.repo.full_name}*",
        "👤 Author: *#{pr.user.login}*",
        "Changes: 🟢 +#{pr.additions} | 🔴 -#{pr.deletions}",
        "`#{pr.base.ref}` ⬅️ `#{pr.head.ref}`",
        "🕒 #{opened_since}", ":zzz: #{stale_since}"
      )
      .add_divider
  end
end
