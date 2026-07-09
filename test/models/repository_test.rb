require "test_helper"

class RepositoryTest < ActiveSupport::TestCase
  test "valid with owner and name" do
    repository = Repository.new(owner: "akitaonrails", name: "easy-ffmpeg")
    assert repository.valid?
  end

  test "invalid without owner or name" do
    assert_not Repository.new(owner: "", name: "x").valid?
    assert_not Repository.new(owner: "x", name: "").valid?
  end

  test "rejects owner or name with unsafe characters" do
    assert_not Repository.new(owner: "a/b", name: "x").valid?
    assert_not Repository.new(owner: "a", name: "x y").valid?
    assert Repository.new(owner: "a-b_c.d", name: "x.y-z_1").valid?
  end

  test "rejects dot-only path segments" do
    assert_not Repository.new(owner: "..", name: "x").valid?
    assert_not Repository.new(owner: "a", name: ".").valid?
    assert_not Repository.new(owner: "a", name: "..").valid?
    assert Repository.new(owner: "a", name: "x..y").valid?
  end

  test "name must be unique per owner ignoring case" do
    existing = repositories(:ai_memory)
    duplicate = Repository.new(owner: existing.owner, name: existing.name.upcase)
    assert_not duplicate.valid?
  end

  test "full_name and github_url" do
    repository = repositories(:ai_memory)
    assert_equal "akitaonrails/ai-memory", repository.full_name
    assert_equal "https://github.com/akitaonrails/ai-memory", repository.github_url
  end

  test "sync lifecycle transitions" do
    repository = repositories(:frank_go)

    repository.start_sync!
    assert repository.syncing?

    repository.finish_sync!
    assert_equal "synced", repository.sync_status
    assert_not_nil repository.last_synced_at

    repository.fail_sync!("boom")
    assert_equal "failed", repository.sync_status
    assert_equal "boom", repository.sync_error
  end

  test "destroying a repository removes its commits and workflow runs" do
    repository = repositories(:ai_memory)

    assert_difference "Commit.count", -repository.commits.count do
      assert_difference "WorkflowRun.count", -repository.workflow_runs.count do
        repository.destroy!
      end
    end
  end
end
