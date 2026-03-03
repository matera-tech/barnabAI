# frozen_string_literal: true

class Actions::Github::ReopenPRAction < Actions::BaseAction
  include Actions::HasFunctionMetadata

  function_code "github_reopen_pr"
  function_description "Reopen a previously closed pull request. Use this when the user wants to reopen a PR that was closed without merging."
  function_parameters({
                        type: "object",
                        properties: {
                          pr_number: {
                            type: "integer",
                            description: "The PR number to reopen. Can often be extracted from a URL or the user messages."
                          },
                          repository: {
                            type: "string",
                            description: "The repository in the format 'owner/repo'"
                          }
                        },
                        required: ["pr_number", "repository"]
                      })

  def execute(parameters)
    pr_number = parameters[:pr_number]
    repository = parameters[:repository]

    raise ArgumentError, "PR number is required" unless pr_number
    raise ArgumentError, "Repository is required" unless repository

    client = Octokit::Client.new(access_token: @user.primary_github_token.token)
    client.update_pull_request(repository, pr_number, state: "open")

    "Reopened <https://github.com/#{repository}/pull/#{pr_number}|PR ##{pr_number}> successfully."
  end
end
