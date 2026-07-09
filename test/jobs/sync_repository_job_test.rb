require "test_helper"

class SyncRepositoryJobTest < ActiveSupport::TestCase
  setup do
    ENV["GITHUB_TOKEN"] = "test-token"
    @repository = repositories(:frank_go)
  end

  teardown do
    ENV.delete("GITHUB_TOKEN")
  end

  test "syncs commits and workflow runs, then marks repository synced" do
    stub_request(:post, "https://api.github.com/graphql")
      .to_return(status: 200, headers: github_headers,
                 body: graphql_history_body(commits: [ graphql_commit(sha: "abc123") ],
                                            description: "Fresh description"))
    stub_request(:get, %r{/repos/akitaonrails/frank_go/actions/runs})
      .to_return(status: 200, headers: github_headers,
                 body: { workflow_runs: [ rest_workflow_run(id: 42) ] }.to_json)

    SyncRepositoryJob.perform_now(@repository)
    @repository.reload

    assert_equal "synced", @repository.sync_status
    assert_equal "Fresh description", @repository.description
    assert_equal "main", @repository.default_branch
    assert_equal [ "abc123" ], @repository.commits.pluck(:sha)
    assert_equal [ 42 ], @repository.workflow_runs.pluck(:github_id)
    assert_not_nil @repository.last_synced_at
    assert_nil @repository.sync_progress
  end

  test "is idempotent thanks to upserts" do
    stub_request(:post, "https://api.github.com/graphql")
      .to_return(status: 200, headers: github_headers,
                 body: graphql_history_body(commits: [ graphql_commit(sha: "abc123") ]))
    stub_request(:get, %r{/actions/runs})
      .to_return(status: 200, headers: github_headers,
                 body: { workflow_runs: [ rest_workflow_run(id: 42) ] }.to_json)

    2.times { SyncRepositoryJob.perform_now(@repository.reload) }

    assert_equal 1, @repository.commits.count
    assert_equal 1, @repository.workflow_runs.count
  end

  test "marks repository failed when GitHub errors" do
    stub_request(:post, "https://api.github.com/graphql").to_return(status: 502, body: "bad gateway")

    SyncRepositoryJob.perform_now(@repository)
    @repository.reload

    assert_equal "failed", @repository.sync_status
    assert_match(/502/, @repository.sync_error)
  end
end
