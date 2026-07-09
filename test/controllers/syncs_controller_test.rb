require "test_helper"

class SyncsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "create enqueues a sync job" do
    assert_enqueued_with(job: SyncRepositoryJob, args: [ repositories(:ai_memory) ]) do
      post repository_sync_url(owner: "akitaonrails", name: "ai-memory")
    end

    assert_redirected_to repository_url(owner: "akitaonrails", name: "ai-memory")
  end

  test "create 404s for unknown repositories" do
    post repository_sync_url(owner: "akitaonrails", name: "nope")
    assert_response :not_found
  end
end
