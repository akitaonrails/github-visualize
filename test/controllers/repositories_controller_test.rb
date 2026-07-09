require "test_helper"

class RepositoriesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "show renders the visualizations for a repository" do
    get repository_url(owner: "akitaonrails", name: "ai-memory")

    assert_response :success
    assert_match "akitaonrails/ai-memory", response.body
    assert_match "data-controller=\"timeline\"", response.body
    assert_match "data-controller=\"heatmap\"", response.body
    assert_match "data-controller=\"ci-lanes\"", response.body
  end

  test "show 404s for unknown repositories" do
    get repository_url(owner: "akitaonrails", name: "does-not-exist")
    assert_response :not_found
  end

  test "create adds a repository and enqueues a sync" do
    assert_difference "Repository.count", 1 do
      assert_enqueued_with(job: SyncRepositoryJob) do
        post repositories_url, params: { full_name: "akitaonrails/easy-ffmpeg" }
      end
    end

    assert_redirected_to repository_url(owner: "akitaonrails", name: "easy-ffmpeg")
  end

  test "create rejects malformed names" do
    assert_no_difference "Repository.count" do
      post repositories_url, params: { full_name: "not-a-full-name" }
    end

    assert_redirected_to root_url
    follow_redirect!
    assert_match(/can.t be blank|invalid/i, response.body)
  end

  test "create rejects duplicates" do
    assert_no_difference "Repository.count" do
      post repositories_url, params: { full_name: "akitaonrails/ai-memory" }
    end

    assert_redirected_to root_url
  end

  test "destroy removes the repository" do
    assert_difference "Repository.count", -1 do
      delete repository_url(owner: "akitaonrails", name: "ai-memory")
    end

    assert_redirected_to root_url
  end
end
