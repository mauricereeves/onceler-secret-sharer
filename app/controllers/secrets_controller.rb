class SecretsController < ApplicationController
  before_action :find_secret, only: [ :show, :destroy ]

  def index
    @recent_secrets = Secret.where(created_by_ip: current_ip)
                            .order(created_at: :desc)
                            .limit(10)
  end

  def new
    @secret = Secret.new
  end

  def create
    @secret = Secret.new(secret_params)
    @secret.created_by_ip = current_ip
    @secret.content = params[:secret][:content]

    if @secret.save
      @secret.log_access("created", current_ip, current_user_agent)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # oh no the secret is gone. get out
    unless @secret
      log_failed_attempt(params[:id])
      render :not_found, status: :not_found
      return
    end

    # secret has expired or no longer viewable. bug out
    unless @secret.can_be_viewed?
      @secret.log_access("failed attempt", current_ip, current_user_agent, "Secret already viewed or expired")
      render :expired, status: :gone
      return
    end

    @content = @secret.content
    @secret.mark_as_viewed!(current_ip, current_user_agent)

    # clear the content from memory. it's gone. poof
    @secret = nil
  end

  def created
    @secret = Secret.find_by(token: params[:token])
    unless @secret
      redirect_to root_path
      return
    end

    @url = @secret.public_url
  end

  def logs
    # for admin purposes, allow the admin user the ability to see
    # the secrets being created
    @logs = AccessLog.includes(:secret).recent.limit(100)
  end

  private

  def find_secret
    @secret = Secret.find_active(params[:id])
  end

  def secret_params
    params.require(:secret).permit(:expires_at, :max_views)
  end

  def log_failed_attempt(token)
    # Log attempt to access non-existent secret
    AccessLog.create(
      secret_id: nil,
      action: "failed_attempt",
      ip_address: current_ip,
      user_agent: current_user_agent,
      details: "Attempted to access non-existent secret: #{token}",
      accessed_at: Time.current
    )
  end
end
