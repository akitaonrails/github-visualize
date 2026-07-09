class CreateRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :repositories do |t|
      t.string :owner, null: false
      t.string :name, null: false
      t.string :default_branch
      t.string :description
      t.datetime :last_synced_at
      t.string :sync_status, null: false, default: "pending"
      t.string :sync_error

      t.timestamps
    end
    add_index :repositories, [ :owner, :name ], unique: true
  end
end
