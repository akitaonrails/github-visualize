require "test_helper"

class SyncAllRepositoriesJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "enqueues a sync for every repository" do
    assert_enqueued_jobs Repository.count, only: SyncRepositoryJob do
      SyncAllRepositoriesJob.perform_now
    end
  end
end
