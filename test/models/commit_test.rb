require "test_helper"

class CommitTest < ActiveSupport::TestCase
  test "requires sha and committed_at" do
    commit = Commit.new(repository: repositories(:ai_memory))
    assert_not commit.valid?
    assert_includes commit.errors.attribute_names, :sha
    assert_includes commit.errors.attribute_names, :committed_at
  end

  test "sha unique per repository" do
    existing = commits(:first)
    duplicate = Commit.new(repository: existing.repository, sha: existing.sha, committed_at: Time.current)
    assert_not duplicate.valid?
  end

  test "summary truncates long messages" do
    commit = Commit.new(message: "x" * 300)
    assert_operator commit.summary.length, :<=, 100
  end
end
