class CleanupExpiredSecretsJob < ApplicationJob
  queue_as :default

  def perform
    expired_count = Secret.expired.count
    Secret.expired.destroy_all

    Rails.logger.info "Cleaned up #{expired_count} expired secrets"
  end
end
