# frozen_string_literal: true

class Actions::Github::ListTeamsAction < Actions::BaseAction
  include Actions::HasFunctionMetadata

  function_code "github_list_teams"
  function_description "List GitHub teams. Without a username, returns all teams across the user's " \
                       "organizations — use this to resolve ambiguous team references. " \
                       "With a username, returns only teams that user belongs to."
  function_parameters({
    type: "object",
    properties: {
      username: { type: "string", description: "GitHub username. Omit to list all organization teams." }
    },
    required: []
  })

  def execute(parameters = {})
    username = parameters[:username].presence
    teams = github_client.list_teams(username: username)

    if teams.empty?
      label = username || "your organizations"
      return "No teams found for #{label}."
    end

    teams.map { |t| { handle: t[:handle], name: t[:name], organization: t[:organization] } }
  end
end
