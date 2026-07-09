require "test_helper"

module Visualizations
  class RepositoryOverviewTest < ActiveSupport::TestCase
    test "aggregates stats per repository" do
      repositories = Repository.all.to_a
      overview = RepositoryOverview.new(repositories)

      stats = overview.for(repositories(:ai_memory))
      assert_equal 4, stats.total_commits
      assert_equal 440, stats.total_additions
      assert_equal 60, stats.total_deletions
      assert_equal "success", stats.ci_conclusion # latest run wins
      assert_equal RepositoryOverview::CHIP_DAYS, stats.daily_counts.size
      assert_equal 4, stats.daily_counts.sum # all fixture commits are recent
      assert_equal 2, stats.max_daily

      empty_stats = overview.for(repositories(:frank_go))
      assert_equal 0, empty_stats.total_commits
      assert_nil empty_stats.ci_conclusion
      assert_equal 0, empty_stats.daily_counts.sum
    end
  end
end
