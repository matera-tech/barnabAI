# frozen_string_literal: true

class PullRequest < ApplicationRecord
  validates :number, presence: true, uniqueness: { scope: :repository_full_name }
  validates :repository_full_name, presence: true

  # Works with both webhook payloads (Hash) and Octokit responses (Sawyer::Resource)
  def apply_pr_data(data)
    assign_attributes(
      github_pr_id: data["id"].to_s,
      title: data["title"],
      body: data["body"],
      state: data["state"],
      author: data["user"]&.[]("login"),
      assignees: Array(data["assignees"]).map { |a| a["login"] },
      base_branch: data["base"]&.[]("ref"),
      base_sha: data["base"]&.[]("sha"),
      head_branch: data["head"]&.[]("ref"),
      head_sha: data["head"]&.[]("sha"),
      github_created_at: data["created_at"],
      github_updated_at: data["updated_at"],
      github_merged_at: data["merged_at"]
    )
  end
end
