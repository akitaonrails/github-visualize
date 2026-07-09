require "test_helper"

module Github
  class ClientTest < ActiveSupport::TestCase
    setup do
      @client = Client.new(token: "test-token")
    end

    test "raises when token is missing" do
      assert_raises(Client::MissingTokenError) { Client.new(token: nil) }
      assert_raises(Client::MissingTokenError) { Client.new(token: "") }
    end

    test "repository_overview returns metadata and commits" do
      stub_request(:post, "https://api.github.com/graphql")
        .with(headers: { "Authorization" => "Bearer test-token" })
        .to_return(status: 200, headers: github_headers,
                   body: graphql_history_body(commits: [ graphql_commit(sha: "abc123") ]))

      overview = @client.repository_overview("akitaonrails", "ai-memory")

      assert_equal "Test repo", overview[:description]
      assert_equal "main", overview[:default_branch]
      assert_equal 1, overview[:commits].size

      commit = overview[:commits].first
      assert_equal "abc123", commit[:sha]
      assert_equal "a commit", commit[:message]
      assert_equal "akitaonrails", commit[:author_login]
      assert_equal 10, commit[:additions]
      assert_equal Time.utc(2026, 7, 1, 12), commit[:committed_at]
    end

    test "repository_overview paginates until max_commits" do
      page_one = graphql_history_body(commits: [ graphql_commit(sha: "one") ],
                                      has_next_page: true, end_cursor: "CURSOR")
      page_two = graphql_history_body(commits: [ graphql_commit(sha: "two") ])

      stub_request(:post, "https://api.github.com/graphql")
        .to_return({ status: 200, headers: github_headers, body: page_one },
                   { status: 200, headers: github_headers, body: page_two })

      overview = @client.repository_overview("akitaonrails", "ai-memory")

      assert_equal %w[one two], overview[:commits].map { |commit| commit[:sha] }
    end

    test "repository_overview raises NotFoundError for unknown repos" do
      stub_request(:post, "https://api.github.com/graphql")
        .to_return(status: 200, headers: github_headers,
                   body: { data: { repository: nil },
                           errors: [ { type: "NOT_FOUND", message: "Could not resolve" } ] }.to_json)

      assert_raises(Client::NotFoundError) do
        @client.repository_overview("akitaonrails", "nope")
      end
    end

    test "workflow_runs maps and paginates REST responses" do
      first_page = { workflow_runs: Array.new(100) { |i| rest_workflow_run(id: i + 1) } }
      second_page = { workflow_runs: [ rest_workflow_run(id: 500, conclusion: "failure") ] }

      stub_request(:get, %r{https://api\.github\.com/repos/akitaonrails/ai-memory/actions/runs})
        .to_return({ status: 200, headers: github_headers, body: first_page.to_json },
                   { status: 200, headers: github_headers, body: second_page.to_json })

      runs = @client.workflow_runs("akitaonrails", "ai-memory")

      assert_equal 101, runs.size
      assert_equal "failure", runs.last[:conclusion]
      assert_equal "ci", runs.first[:workflow_name]
      assert_equal Time.utc(2026, 7, 1, 12, 5), runs.first[:run_started_at]
    end

    test "raises Error on server errors" do
      stub_request(:get, %r{https://api\.github\.com/repos/.+/actions/runs})
        .to_return(status: 500, body: "oops")

      assert_raises(Client::Error) { @client.workflow_runs("akitaonrails", "ai-memory") }
    end

    test "raises NotFoundError on 404" do
      stub_request(:get, %r{https://api\.github\.com/repos/.+/actions/runs})
        .to_return(status: 404, body: "{}")

      assert_raises(Client::NotFoundError) { @client.workflow_runs("akitaonrails", "gone") }
    end
  end
end
