require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "index lists monitored repositories" do
    get root_url

    assert_response :success
    assert_select "h1", text: /2\s+repos/
    assert_select "a", text: "akitaonrails/ai-memory"
    assert_select "a", text: "akitaonrails/frank_go"
  end

  test "index defaults to most recently worked on first" do
    get root_url

    body = response.body
    cards = body[body.index("sort")..] # ai-memory has recent commits, frank_go none
    assert_operator cards.index("akitaonrails/ai-memory"), :<, cards.index("akitaonrails/frank_go")
  end

  test "index sorts by name descending" do
    get root_url(sort: "name_desc")

    body = response.body
    cards = body[body.index("sort")..]
    assert_operator cards.index("akitaonrails/frank_go"), :<, cards.index("akitaonrails/ai-memory")
  end

  test "index falls back to default sort on bogus param" do
    get root_url(sort: "evil_injection")
    assert_response :success
  end

  test "index renders empty state without repositories" do
    Repository.destroy_all
    get root_url

    assert_response :success
    assert_match(/No repositories yet/, response.body)
  end
end
