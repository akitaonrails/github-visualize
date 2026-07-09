require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "index lists monitored repositories" do
    get root_url

    assert_response :success
    assert_select "h1", text: /2\s+repos/
    assert_select "a", text: "akitaonrails/ai-memory"
    assert_select "a", text: "akitaonrails/frank_go"
  end

  test "index renders empty state without repositories" do
    Repository.destroy_all
    get root_url

    assert_response :success
    assert_match(/No repositories yet/, response.body)
  end
end
