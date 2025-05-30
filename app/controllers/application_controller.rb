class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  protect_from_forgery with: :exception

  private

  def current_ip
    request.remote_ip
  end

  def current_user_agent
    request.user_agent
  end
end
