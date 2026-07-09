class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Opt-in HTTP Basic auth for deployments exposed beyond a trusted LAN.
  # Set both HTTP_BASIC_USER and HTTP_BASIC_PASSWORD to enable; the /up
  # health check is served by Rails::HealthController and stays open.
  before_action :require_basic_auth

  private

  def require_basic_auth
    expected_user = ENV["HTTP_BASIC_USER"]
    expected_password = ENV["HTTP_BASIC_PASSWORD"]
    return if expected_user.blank? || expected_password.blank?

    authenticate_or_request_with_http_basic("github-visualize") do |user, password|
      ActiveSupport::SecurityUtils.secure_compare(user, expected_user) &
        ActiveSupport::SecurityUtils.secure_compare(password, expected_password)
    end
  end
end
