class SyncAllRepositoriesJob < ApplicationJob
  queue_as :default

  # Sync cadence is tiered by recent activity (see config/recurring.yml):
  # hot repos poll every 10 minutes, warm hourly, cold every 6 hours.
  HOT_WINDOW = 7.days
  WARM_WINDOW = 30.days
  TIERS = %w[hot warm cold].freeze

  def perform(tier = nil)
    last_commits = Commit.group(:repository_id).maximum(:committed_at)

    Repository.find_each do |repository|
      next unless tier.nil? || tier_for(repository, last_commits[repository.id]) == tier.to_s

      SyncRepositoryJob.perform_later(repository)
    end
  end

  private

  # Repos without commits tier by when they were added, so a fresh repo
  # polls frequently until its first sync lands.
  def tier_for(repository, last_committed_at)
    reference = last_committed_at || repository.created_at

    if reference >= HOT_WINDOW.ago then "hot"
    elsif reference >= WARM_WINDOW.ago then "warm"
    else "cold"
    end
  end
end
