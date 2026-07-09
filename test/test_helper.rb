require "simplecov"
SimpleCov.start "rails" do
  add_group "Presenters", "app/presenters"
  add_group "Services", "app/services"
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

# Tests must never see the developer's real credentials from the shell;
# individual tests set these explicitly when they need them.
ENV.delete("GITHUB_TOKEN")
ENV.delete("GITHUB_OWNER")

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    parallelize_setup do |worker|
      SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
    end

    parallelize_teardown do
      SimpleCov.result
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def github_headers
      { "Content-Type" => "application/json" }
    end

    # Builds a GraphQL commit-history response body like api.github.com/graphql returns.
    def graphql_history_body(commits:, has_next_page: false, end_cursor: nil,
                             description: "Test repo", default_branch: "main")
      {
        data: {
          repository: {
            description: description,
            defaultBranchRef: {
              name: default_branch,
              target: {
                history: {
                  pageInfo: { hasNextPage: has_next_page, endCursor: end_cursor },
                  nodes: commits
                }
              }
            }
          }
        }
      }.to_json
    end

    def graphql_commit(sha:, message: "a commit", committed_at: "2026-07-01T12:00:00Z",
                       additions: 10, deletions: 2, login: "akitaonrails")
      {
        oid: sha,
        messageHeadline: message,
        committedDate: committed_at,
        additions: additions,
        deletions: deletions,
        author: { user: { login: login }, name: "Akita" }
      }
    end

    def rest_workflow_run(id:, name: "ci", run_number: 1, conclusion: "success",
                          started_at: "2026-07-01T12:05:00Z")
      {
        id: id,
        name: name,
        run_number: run_number,
        status: "completed",
        conclusion: conclusion,
        head_branch: "main",
        run_started_at: started_at
      }
    end
  end
end
