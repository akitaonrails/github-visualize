class CreateWorkflowRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :workflow_runs do |t|
      t.references :repository, null: false, foreign_key: true
      t.integer :github_id, null: false, limit: 8
      t.string :workflow_name
      t.integer :run_number
      t.string :status
      t.string :conclusion
      t.string :branch
      t.datetime :run_started_at

      t.timestamps
    end
    add_index :workflow_runs, [ :repository_id, :github_id ], unique: true
    add_index :workflow_runs, [ :repository_id, :run_started_at ]
  end
end
