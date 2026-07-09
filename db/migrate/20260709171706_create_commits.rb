class CreateCommits < ActiveRecord::Migration[8.1]
  def change
    create_table :commits do |t|
      t.references :repository, null: false, foreign_key: true
      t.string :sha, null: false
      t.string :message
      t.string :author_login
      t.datetime :committed_at, null: false
      t.integer :additions, null: false, default: 0
      t.integer :deletions, null: false, default: 0

      t.timestamps
    end
    add_index :commits, [ :repository_id, :sha ], unique: true
    add_index :commits, [ :repository_id, :committed_at ]
  end
end
