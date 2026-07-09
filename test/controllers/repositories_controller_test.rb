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

  test "show honors the days window param and falls back on invalid values" do
    get repository_url(owner: "akitaonrails", name: "ai-memory", params: { days: 15 })
    assert_response :success
    assert_match "last 15 days", response.body

    get repository_url(owner: "akitaonrails", name: "ai-memory", params: { days: 999 })
    assert_response :success
    assert_match "last 42 days", response.body
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

  test "create scopes bare names to GITHUB_OWNER" do
    ENV["GITHUB_OWNER"] = "akitaonrails"

    assert_difference "Repository.count", 1 do
      post repositories_url, params: { full_name: "easy-subtitle" }
    end

    assert_redirected_to repository_url(owner: "akitaonrails", name: "easy-subtitle")
  ensure
    ENV.delete("GITHUB_OWNER")
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
