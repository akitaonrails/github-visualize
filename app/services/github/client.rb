require "net/http"

module Github
  # Minimal GitHub API client. Commit history comes from the GraphQL API
  # because it returns additions/deletions in bulk (100 commits per request);
  # the REST equivalent needs one request per commit for the same data.
  class Client
    Error = Class.new(StandardError)
    MissingTokenError = Class.new(Error)
    NotFoundError = Class.new(Error)

    API_HOST = "api.github.com".freeze
    PAGE_SIZE = 100

    HISTORY_QUERY = <<~GRAPHQL.freeze
      query($owner: String!, $name: String!, $since: GitTimestamp, $cursor: String, $pageSize: Int!) {
        repository(owner: $owner, name: $name) {
          description
          defaultBranchRef {
            name
            target {
              ... on Commit {
                history(first: $pageSize, since: $since, after: $cursor) {
                  pageInfo { hasNextPage endCursor }
                  nodes {
                    oid
                    messageHeadline
                    committedDate
                    additions
                    deletions
                    author { user { login } name }
                  }
                }
              }
            }
          }
        }
      }
    GRAPHQL

    def initialize(token: ENV["GITHUB_TOKEN"])
      raise MissingTokenError, "GITHUB_TOKEN is not set" if token.blank?
      @token = token
    end

    # Returns { description:, default_branch:, commits: [ { sha:, message:, ... } ] }
    # with commits newer than +since+, capped at +max_commits+.
    # Yields each page of commits as it arrives when a block is given,
    # so callers can persist and report progress incrementally.
    def repository_overview(owner, name, since: nil, max_commits: 1000)
      commits = []
      cursor = nil
      description = nil
      default_branch = nil

      loop do
        data = graphql(HISTORY_QUERY, owner: owner, name: name, cursor: cursor,
                                      since: since&.iso8601, pageSize: PAGE_SIZE)
        repo = data["repository"] or raise NotFoundError, "#{owner}/#{name} not found"
        description = repo["description"]
        branch_ref = repo["defaultBranchRef"] or break
        default_branch = branch_ref["name"]
        history = branch_ref.dig("target", "history") or break

        page_commits = history["nodes"].map { |node| commit_attributes(node) }
        yield page_commits if block_given? && page_commits.any?
        commits.concat(page_commits)
        page = history["pageInfo"]
        break unless page["hasNextPage"] && commits.size < max_commits
        cursor = page["endCursor"]
      end

      { description: description, default_branch: default_branch, commits: commits.first(max_commits) }
    end

    # Login of the user the token belongs to.
    def authenticated_login
      rest_get("/user")["login"]
    end

    # Repos owned by the token's user (public and private), most recently
    # pushed first. Used for the add-repository autocomplete.
    def user_repositories(max_repos: 300)
      repos = []
      page = 1

      while repos.size < max_repos
        body = rest_get("/user/repos?per_page=#{PAGE_SIZE}&page=#{page}&affiliation=owner&sort=pushed")
        break if body.empty?

        repos.concat(body.map do |repo|
          {
            full_name: repo["full_name"],
            description: repo["description"],
            private: repo["private"]
          }
        end)
        break if body.size < PAGE_SIZE
        page += 1
      end

      repos.first(max_repos)
    end

    # Returns newest-first workflow runs, capped at +max_runs+.
    def workflow_runs(owner, name, max_runs: 300)
      runs = []
      page = 1

      while runs.size < max_runs
        body = rest_get("/repos/#{owner}/#{name}/actions/runs?per_page=#{PAGE_SIZE}&page=#{page}")
        batch = body.fetch("workflow_runs", [])
        break if batch.empty?

        runs.concat(batch.map { |run| workflow_run_attributes(run) })
        break if batch.size < PAGE_SIZE
        page += 1
      end

      runs.first(max_runs)
    end

    private

    def commit_attributes(node)
      {
        sha: node["oid"],
        message: node["messageHeadline"],
        author_login: node.dig("author", "user", "login") || node.dig("author", "name"),
        committed_at: Time.iso8601(node["committedDate"]),
        additions: node["additions"].to_i,
        deletions: node["deletions"].to_i
      }
    end

    def workflow_run_attributes(run)
      {
        github_id: run["id"],
        workflow_name: run["name"],
        run_number: run["run_number"],
        status: run["status"],
        conclusion: run["conclusion"],
        branch: run["head_branch"],
        run_started_at: run["run_started_at"]&.then { |time| Time.iso8601(time) }
      }
    end

    def graphql(query, **variables)
      body = post_json("/graphql", { query: query, variables: variables.compact })
      if (errors = body["errors"]).present?
        message = errors.map { |error| error["message"] }.join("; ")
        raise errors.any? { |error| error["type"] == "NOT_FOUND" } ? NotFoundError : Error, message
      end
      body.fetch("data")
    end

    def rest_get(path)
      request = Net::HTTP::Get.new(path, headers)
      perform(request)
    end

    def post_json(path, payload)
      request = Net::HTTP::Post.new(path, headers)
      request.body = payload.to_json
      perform(request)
    end

    def perform(request)
      response = http.request(request)
      case response
      when Net::HTTPSuccess then JSON.parse(response.body)
      when Net::HTTPNotFound then raise NotFoundError, "GitHub returned 404 for #{request.path}"
      else
        raise Error, "GitHub returned #{response.code} for #{request.path}"
      end
    rescue JSON::ParserError, Timeout::Error, SystemCallError, OpenSSL::SSL::SSLError => e
      raise Error, "GitHub request failed: #{e.message}"
    end

    def http
      Net::HTTP.new(API_HOST, 443).tap do |connection|
        connection.use_ssl = true
        connection.open_timeout = 10
        connection.read_timeout = 30
      end
    end

    def headers
      {
        "Authorization" => "Bearer #{@token}",
        "Accept" => "application/vnd.github+json",
        "X-GitHub-Api-Version" => "2022-11-28",
        "User-Agent" => "github-visualize"
      }
    end
  end
end
