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

  test "index returns empty list when GitHub errors" do
    stub_request(:get, %r{https://api\.github\.com/user/repos}).to_return(status: 500)

    get suggestions_url(q: "x")

    assert_response :success
    assert_equal [], response.parsed_body
  end
end
