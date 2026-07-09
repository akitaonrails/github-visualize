class AddSyncProgressToRepositories < ActiveRecord::Migration[8.1]
  def change
    add_column :repositories, :sync_progress, :string
  end
end
