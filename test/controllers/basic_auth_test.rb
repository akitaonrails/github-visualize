require "test_helper"

class BasicAuthTest < ActionDispatch::IntegrationTest
  setup do
    ENV["HTTP_BASIC_USER"] = "admin"
    ENV["HTTP_BASIC_PASSWORD"] = "hunter2"
  end

  teardown do
    ENV.delete("HTTP_BASIC_USER")
    ENV.delete("HTTP_BASIC_PASSWORD")
  end

  test "rejects requests without credentials when enabled" do
    get root_url
    assert_response :unauthorized
  end

  test "accepts requests with valid credentials" do
    get root_url, headers: {
      "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "hunter2")
    }
    assert_response :success
  end

  test "rejects wrong credentials" do
    get root_url, headers: {
      "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "wrong")
    }
    assert_response :unauthorized
  end

  test "health check stays open" do
    get rails_health_check_url
    assert_response :success
  end

  test "disabled when env vars are absent" do
    ENV.delete("HTTP_BASIC_USER")
    ENV.delete("HTTP_BASIC_PASSWORD")

    get root_url
    assert_response :success
  end
end
