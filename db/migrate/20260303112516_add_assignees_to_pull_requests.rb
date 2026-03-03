class AddAssigneesToPullRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :pull_requests, :assignees, :string, array: true, default: []
  end
end
