require "test_helper"

module Visualizations
  class CommitTimelineTest < ActiveSupport::TestCase
    test "totals and buckets add up" do
      timeline = CommitTimeline.new(repositories(:ai_memory)).to_h

      assert_equal 4, timeline[:total_commits]
      assert_equal 440, timeline[:total_additions]
      assert_equal 60, timeline[:total_deletions]

      assert_equal 4, timeline[:buckets].sum { |bucket| bucket[:count] }
      assert_equal 440, timeline[:buckets].sum { |bucket| bucket[:additions] }
      assert_equal 60, timeline[:buckets].sum { |bucket| bucket[:deletions] }

      assert_equal 4, timeline[:log].size
      assert_equal "Tune retrieval ranking", timeline[:log].last[:message]
      assert_match(/commits in/, timeline[:peak])
    end

    test "window excludes older commits" do
      timeline = CommitTimeline.new(repositories(:ai_memory), window_days: 7).to_h

      assert_equal 3, timeline[:total_commits] # 10-day-old commit falls outside
      assert_equal 340, timeline[:total_additions]
      assert_equal 60, timeline[:total_deletions]
      assert_equal 3, timeline[:log].size
    end

    test "empty repository yields empty timeline" do
      timeline = CommitTimeline.new(repositories(:frank_go)).to_h

      assert_equal 0, timeline[:total_commits]
      assert_empty timeline[:buckets]
      assert_empty timeline[:log]
    end
  end
end
