require "test_helper"

class SuggestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV["GITHUB_TOKEN"] = "test-token"
    Rails.cache.clear
  end

  teardown do
    ENV.delete("GITHUB_TOKEN")
  end

  test "index filters by query and excludes monitored repos" do
    stub_request(:get, %r{https://api\.github\.com/user/repos})
      .to_return(status: 200, headers: github_headers, body: [
        { full_name: "akitaonrails/ai-memory", description: "already monitored", private: false },
        { full_name: "akitaonrails/ai-jail", description: "sandbox", private: false },
        { full_name: "akitaonrails/secret-stuff", description: nil, private: true },
        { full_name: "akitaonrails/frank_mega", description: "downloader", private: false }
      ].to_json)

    get suggestions_url(q: "ai")

    assert_response :success
    names = response.parsed_body.map { |repo| repo["full_name"] }
    assert_includes names, "akitaonrails/ai-jail"
    assert_not_includes names, "akitaonrails/ai-memory" # already monitored
    assert_not_includes names, "akitaonrails/frank_mega" # doesn't match query
  end

  test "display_name drops the prefix for the configured owner" do
    ENV["GITHUB_OWNER"] = "akitaonrails"
    stub_request(:get, %r{https://api\.github\.com/user/repos})
      .to_return(status: 200, headers: github_headers, body: [
        { full_name: "akitaonrails/ai-jail", description: nil, private: false },
        { full_name: "someoneelse/ai-tool", description: nil, private: false }
      ].to_json)

    get suggestions_url(q: "ai")

    display_names = response.parsed_body.map { |repo| repo["display_name"] }
    assert_includes display_names, "ai-jail"
    assert_includes display_names, "someoneelse/ai-tool"
  ensure
    ENV.delete("GITHUB_OWNER")
  end

  test "index finds org repos by owner, ranking name matches first" do
    stub_request(:get, %r{https://api\.github\.com/user/repos})
      .to_return(status: 200, headers: github_headers, body: [
        { full_name: "BLUE3-ISP/eop", description: "org repo", private: true },
        { full_name: "samirhvbr/blue3-notes", description: "personal", private: false }
      ].to_json)

    get suggestions_url(q: "blue3")

    names = response.parsed_body.map { |repo| repo["full_name"] }
    assert_includes names, "BLUE3-ISP/eop"          # matched on the owner
    assert_includes names, "samirhvbr/blue3-notes"  # matched on the name
    assert_equal "samirhvbr/blue3-notes", names.first # name match ranks above owner-only
  end

  test "index still matches on the repo name segment" do
    stub_request(:get, %r{https://api\.github\.com/user/repos})
      .to_return(status: 200, headers: github_headers, body: [
        { full_name: "BLUE3-ISP/eop", description: nil, private: true },
        { full_name: "samirhvbr/other", description: nil, private: false }
      ].to_json)

    get suggestions_url(q: "eop")

    names = response.parsed_body.map { |repo| repo["full_name"] }
    assert_equal [ "BLUE3-ISP/eop" ], names
  end

  test "index returns empty list when GitHub errors" do
    stub_request(:get, %r{https://api\.github\.com/user/repos}).to_return(status: 500)

    get suggestions_url(q: "x")

    assert_response :success
    assert_equal [], response.parsed_body
  end
end
