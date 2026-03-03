# frozen_string_literal: true

module Github
  module HasGraphqlQuery
    extend ActiveSupport::Concern

    def run_graphql(access_token, query, variables = {})
      @client ||= Octokit::Client.new(access_token:)

      response = @client.post('/graphql', { query: query, variables: variables }.to_json)
      payload = response.to_h

      if payload[:errors]
        raise "GraphQLError: #{payload.dig(:errors).map { |e| e[:message] }.join(', ')}"
      end

      payload[:data]
    end
  end
end
