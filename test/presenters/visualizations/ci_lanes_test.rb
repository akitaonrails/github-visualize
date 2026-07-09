require "test_helper"

module Visualizations
  class CiLanesTest < ActiveSupport::TestCase
    test "groups runs into lanes and counts green workflows" do
      lanes = CiLanes.new(repositories(:ai_memory)).to_h

      assert_equal 2, lanes[:total_lanes]
      assert_equal 1, lanes[:green_lanes] # ci ends green, release ends red
      assert_equal %w[ci release], lanes[:lanes].map { |lane| lane[:name] }

      ci_lane = lanes[:lanes].first
      assert ci_lane[:green]
      assert_equal %w[red green], ci_lane[:runs].map { |run| run[:state] }
      assert_operator lanes[:from], :<, lanes[:to]
    end

    test "window excludes older runs" do
      lanes = CiLanes.new(repositories(:ai_memory), window_days: 3).to_h

      assert_equal 2, lanes[:total_lanes]
      assert_equal 2, lanes[:lanes].sum { |lane| lane[:runs].size } # 6-day-old run excluded
      assert_equal %w[green], lanes[:lanes].first[:runs].map { |run| run[:state] }
    end

    test "empty repository yields no lanes" do
      lanes = CiLanes.new(repositories(:frank_go)).to_h

      assert_equal 0, lanes[:total_lanes]
      assert_empty lanes[:lanes]
      assert_nil lanes[:from]
    end
  end
end
