class SyncAllRepositoriesJob < ApplicationJob
  queue_as :default

  def perform
    Repository.find_each { |repository| SyncRepositoryJob.perform_later(repository) }
  end
end
