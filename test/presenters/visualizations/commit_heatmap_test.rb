require "test_helper"

module Visualizations
  class CommitHeatmapTest < ActiveSupport::TestCase
    test "buckets commits by day and hour" do
      heatmap = CommitHeatmap.new(repositories(:ai_memory)).to_h

      assert_equal 4, heatmap[:total]
      assert_equal 2, heatmap[:max] # two commits in the same 5.days.ago hour

      row = heatmap[:rows].find { |r| r[:label] == 5.days.ago.in_time_zone.strftime("%b %-d") }
      assert_equal 2, row[:counts][14]
      assert_equal 24, row[:counts].size
    end

    test "empty repository produces empty rows" do
      heatmap = CommitHeatmap.new(repositories(:frank_go)).to_h

      assert_equal 0, heatmap[:total]
      assert_equal 0, heatmap[:max]
      assert_empty heatmap[:rows]
    end
  end
end
