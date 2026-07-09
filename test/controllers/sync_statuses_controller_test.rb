require "test_helper"

class SyncStatusesControllerTest < ActionDispatch::IntegrationTest
  test "show returns sync status as JSON" do
    repository = repositories(:ai_memory)
    repository.update!(sync_status: "syncing", sync_progress: "300 commits fetched")

    get repository_sync_status_url(owner: "akitaonrails", name: "ai-memory")

    assert_response :success
    body = response.parsed_body
    assert_equal "syncing", body["status"]
    assert_equal "300 commits fetched", body["progress"]
    assert_equal repository.commits.count, body["commits"]
    assert_equal repository.workflow_runs.count, body["workflow_runs"]
  end

  test "show 404s for unknown repositories" do
    get repository_sync_status_url(owner: "akitaonrails", name: "nope")
    assert_response :not_found
  end
end
