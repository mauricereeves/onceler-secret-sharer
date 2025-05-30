class SecretsController < ApplicationController
  before_action :find_secret, only: [ :show, :destroy ]
  before_action :ensure_creator, only: [ :destroy ]

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
      redirect_to secret_created_path(@secret.token)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # oh no the secret is gone. get out
    unless @secret
      log_failed_attempt(params[:token])
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

  def destroy
    @secret.update!(revoked: true)
    @secret.log_access("manually_revoked", current_ip, current_user_agent, "Secret manually revoked by creator")

    # go back to whence we came
    redirect_to secrets_path, notice: "Secret has been revoked successfully"
  end

  def logs
    # for admin purposes, allow the admin user the ability to see
    # the secrets being created
    @logs = AccessLog.includes(:secret).recent.limit(100)
  end

  private

  # handle the finding of the secret so we can act on it
  def find_secret
    if action_name == "destroy"
      # don't care about active status if we're going to destroy
      @secret = Secret.where(revoked: false).find_by(token: params[:token])
    else
      @secret = Secret.find_active(params[:token])
    end
  end

  # ensure the person making the request is the same as the
  # original creator of the secret. this unlocks super magical
  # destroy powers
  def ensure_creator
    unless @secret && @secret.created_by_ip == current_ip
      redirect_to secrets_path, alert: "‽ You can only destroy secrets you created."
      nil
    end
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
