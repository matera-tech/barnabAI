# frozen_string_literal: true

class Actions::Database::ListPrsByTeamsAction < Actions::BaseAction
  include Actions::HasFunctionMetadata

  function_code "db_list_prs_by_teams"
  function_description "Search merged pull requests by team ownership from the local database. " \
                       "Only merged PRs are tracked — open or closed (unmerged) PRs will not appear in results. " \
                       "Teams are derived from CODEOWNERS; pass team handles like '@org/team-name'. " \
                       "Use the github_list_teams action first to resolve ambiguous team names to exact handles. " \
                       "Returns structured data (repository, PR number, teams) that can be used with other actions like github_get_pr_details."
  function_parameters({
    type: "object",
    properties: {
      teams: {
        type: "array",
        items: { type: "string" },
        description: "Team handles to filter by (e.g., ['@organization/core-team', '@rails/founders']). Be flexible with typos and partial matches."
      },
      days: {
        type: "integer",
        description: "Number of days to look back. Examples: 'last 3 days' -> 3, 'past week' -> 7, 'last month' -> 30. Defaults to 7 if not specified."
      }
    },
    required: ["teams"]
  })

  def execute(parameters)
    teams = parameters[:teams] || parameters["teams"]
    raise ArgumentError, "Teams are required" unless teams&.any?

    teams_array = teams.is_a?(Array) ? teams : [teams]
    teams_array = teams_array.map { |team| team.start_with?("@") ? team : "@#{team}" }

    days = (parameters[:days] || parameters["days"] || 7).to_i
    days = 7 if days <= 0
    cutoff_date = days.days.ago

    team_conditions = teams_array.map { "impacted_teams::text[] @> ARRAY[?]::text[]" }
    matching_prs = PullRequest
      .where("(#{team_conditions.join(' OR ')})", *teams_array)
      .where("github_created_at >= ?", cutoff_date)
      .order(github_created_at: :desc)
      .limit(50)

    return "No merged PRs found impacting teams #{teams_array.join(', ')} in the last #{days} days." if matching_prs.empty?

    matching_prs.map do |pr|
      {
        repository: pr.repository_full_name,
        number: pr.number,
        title: pr.title,
        author: pr.author,
        impacted_teams: pr.impacted_teams,
        merged_at: pr.github_merged_at&.iso8601
      }
    end
  end
end
