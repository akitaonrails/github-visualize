require "test_helper"

class WorkflowRunTest < ActiveSupport::TestCase
  test "github_id unique per repository" do
    existing = workflow_runs(:ci_latest_success)
    duplicate = WorkflowRun.new(repository: existing.repository, github_id: existing.github_id)
    assert_not duplicate.valid?
  end

  test "green and red predicates" do
    assert workflow_runs(:ci_latest_success).green?
    assert workflow_runs(:ci_old_failure).red?

    cancelled = WorkflowRun.new(conclusion: "cancelled")
    assert_not cancelled.green?
    assert_not cancelled.red?
  end
end
