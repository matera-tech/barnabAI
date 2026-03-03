# frozen_string_literal: true

class Github::TeamsFetcher
  include Github::HasGraphqlQuery

  USER_TEAMS_QUERY = <<~GRAPHQL
    query($login: String!) {
      user(login: $login) {
        organizations(first: 100) {
          nodes {
            login
            teams(first: 100, userLogins: [$login]) {
              nodes { name, slug, description }
            }
          }
        }
      }
    }
  GRAPHQL

  ALL_ORG_TEAMS_QUERY = <<~GRAPHQL
    query($login: String!) {
      user(login: $login) {
        organizations(first: 100) {
          nodes {
            login
            teams(first: 100) {
              nodes { name, slug, description }
            }
          }
        }
      }
    }
  GRAPHQL

  def initialize(user)
    @github_token = user.primary_github_token.token
  end

  # Returns only teams the given user belongs to
  def call(username)
    data = run_graphql(@github_token, USER_TEAMS_QUERY, login: username)
    parse_org_teams(data)
  end

  # Returns all teams across the user's organizations
  def all_org_teams(username)
    data = run_graphql(@github_token, ALL_ORG_TEAMS_QUERY, login: username)
    parse_org_teams(data)
  end

  private

  def parse_org_teams(data)
    orgs = data.dig(:user, :organizations, :nodes) || []
    orgs.flat_map do |org|
      (org.dig(:teams, :nodes) || []).map do |team|
        {
          name: team[:name],
          slug: team[:slug],
          organization: org[:login],
          handle: "@#{org[:login]}/#{team[:slug]}",
          description: team[:description]
        }
      end
    end
  end
end
