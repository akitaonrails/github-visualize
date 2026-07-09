require "test_helper"

class SyncAllRepositoriesJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "without a tier enqueues a sync for every repository" do
    assert_enqueued_jobs Repository.count, only: SyncRepositoryJob do
      SyncAllRepositoriesJob.perform_now
    end
  end

  test "hot tier picks repos with commits in the last 7 days" do
    # ai_memory's newest fixture commit is 1 day old
    assert_enqueued_with(job: SyncRepositoryJob, args: [ repositories(:ai_memory) ]) do
      SyncAllRepositoriesJob.perform_now("hot")
    end
    assert_enqueued_jobs 1, only: SyncRepositoryJob
  end

  test "commitless repos tier by creation date" do
    # frank_go has no commits and was created 20 days ago -> warm
    assert_enqueued_with(job: SyncRepositoryJob, args: [ repositories(:frank_go) ]) do
      SyncAllRepositoriesJob.perform_now("warm")
    end
    assert_enqueued_jobs 1, only: SyncRepositoryJob
  end

  test "cold tier picks repos idle for more than 30 days" do
    stale = Repository.create!(owner: "akitaonrails", name: "stale-repo", created_at: 90.days.ago)
    stale.commits.create!(sha: "e" * 40, committed_at: 60.days.ago)

    assert_enqueued_with(job: SyncRepositoryJob, args: [ stale ]) do
      SyncAllRepositoriesJob.perform_now("cold")
    end
    assert_enqueued_jobs 1, only: SyncRepositoryJob
  end
end
