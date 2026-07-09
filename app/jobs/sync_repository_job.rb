class SyncRepositoryJob < ApplicationJob
  queue_as :default

  INITIAL_COMMIT_LIMIT = 2000
  WORKFLOW_RUN_LIMIT = 300

  def perform(repository)
    repository.start_sync!
    client = Github::Client.new

    sync_commits(repository, client)
    sync_workflow_runs(repository, client)

    repository.finish_sync!
  rescue Github::Client::Error => error
    repository.fail_sync!(error.message)
  end

  private

  # Commits are upserted page by page so the UI can show live progress
  # and partial data survives an interrupted sync.
  def sync_commits(repository, client)
    since = repository.commits.maximum(:committed_at)&.+(1.second)
    fetched = 0

    overview = client.repository_overview(repository.owner, repository.name,
                                          since: since, max_commits: INITIAL_COMMIT_LIMIT) do |batch|
      rows = batch.map { |commit| commit.merge(repository_id: repository.id) }
      Commit.upsert_all(rows, unique_by: %i[repository_id sha])
      fetched += batch.size
      repository.update!(sync_progress: "#{fetched} commits fetched")
    end

    repository.update!(description: overview[:description],
                       default_branch: overview[:default_branch])
  end

  def sync_workflow_runs(repository, client)
    repository.update!(sync_progress: "fetching CI runs")
    runs = client.workflow_runs(repository.owner, repository.name, max_runs: WORKFLOW_RUN_LIMIT)
    rows = runs.map { |run| run.merge(repository_id: repository.id) }
    WorkflowRun.upsert_all(rows, unique_by: %i[repository_id github_id]) if rows.any?
  end
end
