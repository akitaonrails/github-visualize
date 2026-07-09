# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_09_171720) do
  create_table "commits", force: :cascade do |t|
    t.integer "additions", default: 0, null: false
    t.string "author_login"
    t.datetime "committed_at", null: false
    t.datetime "created_at", null: false
    t.integer "deletions", default: 0, null: false
    t.string "message"
    t.integer "repository_id", null: false
    t.string "sha", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_id", "committed_at"], name: "index_commits_on_repository_id_and_committed_at"
    t.index ["repository_id", "sha"], name: "index_commits_on_repository_id_and_sha", unique: true
    t.index ["repository_id"], name: "index_commits_on_repository_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "default_branch"
    t.string "description"
    t.datetime "last_synced_at"
    t.string "name", null: false
    t.string "owner", null: false
    t.string "sync_error"
    t.string "sync_status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["owner", "name"], name: "index_repositories_on_owner_and_name", unique: true
  end

  create_table "workflow_runs", force: :cascade do |t|
    t.string "branch"
    t.string "conclusion"
    t.datetime "created_at", null: false
    t.integer "github_id", limit: 8, null: false
    t.integer "repository_id", null: false
    t.integer "run_number"
    t.datetime "run_started_at"
    t.string "status"
    t.datetime "updated_at", null: false
    t.string "workflow_name"
    t.index ["repository_id", "github_id"], name: "index_workflow_runs_on_repository_id_and_github_id", unique: true
    t.index ["repository_id", "run_started_at"], name: "index_workflow_runs_on_repository_id_and_run_started_at"
    t.index ["repository_id"], name: "index_workflow_runs_on_repository_id"
  end

  add_foreign_key "commits", "repositories"
  add_foreign_key "workflow_runs", "repositories"
end
