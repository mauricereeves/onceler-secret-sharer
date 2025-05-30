# the class that represents a secret. when you share a secret with someone, it
# is encrypted and stored in the database. the secret is then shared with the
# recipient via a url. the recipient can view the secret up to the limit, and then the
# secret is destroyed.
#
# Secrets also have an expiration date after which they are destroyed automatically.
#
# Secrets are encrypted using AES-256-CBC with a random IV. The IV is stored in the
# database and is used to decrypt the secret. The secret is encrypted with the key
# stored in the Rails credentials.
class Secret < ApplicationRecord
  has_many :access_logs, dependent: :destroy

  validates :token, presence: true, uniqueness: true
  validates :encrypted_content, presence: true
  validates :content_iv, presence: true
  validates :expires_at, presence: true
  validates :created_by_ip, presence: true
  validates :max_views, presence: true, numericality: { greater_than: 0 }

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  # set some important scopes
  scope :active, -> { where(revoked: false).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ? or revoked = ?", Time.current, true) }

  def self.find_active(token)
    active.find_by(token: token)
  end

  def expired?
    expires_at <= Time.current || revoked?
  end

  def can_be_viewed?
    !expired? && view_count < max_views
  end

  def content=(plaintext)
    return if plaintext.blank?

    # generate a random iv for this secret
    cipher = OpenSSL::Cipher.new("aes-256-cbc")
    cipher.encrypt
    cipher.key = encryption_key
    iv = cipher.random_iv

    encrypted = cipher.update(plaintext) + cipher.final
    self.encrypted_content = Base64.strict_encode64(encrypted)
    self.content_iv = Base64.strict_encode64(iv)
  end

  def content
    return nil if encrypted_content.blank? || content_iv.blank?

    cipher = OpenSSL::Cipher.new("aes-256-cbc")
    cipher.decrypt
    cipher.key = encryption_key
    cipher.iv = Base64.strict_decode64(content_iv)
    encrypted_data = Base64.strict_decode64(encrypted_content)
    decrypted = cipher.update(encrypted_data) + cipher.final
    decrypted.force_encoding("UTF-8")
  end

  def mark_as_viewed!(ip_address = nil, user_agent = nil)
    transaction do
      increment!(:view_count)
      if view_count >= max_views
        self.update!(revoked: true)
        log_access("revoked", ip_address, user_agent, "Secret revoked after #{max_views} views")
      else
        log_access("viewed", ip_address, user_agent)
      end
    end
  end

  def log_access(action, ip_address, user_agent, details = nil)
    access_logs.create!(
      ip_address: ip_address,
      user_agent: user_agent,
      action: action,
      details: details,
      accessed_at: Time.current
    )
  end

  # get a good url for the secret
  def public_url
    Rails.application.routes.url_helpers.view_secret_url(token, host: Rails.application.routes.default_url_options[:host])
  end

  private

  def generate_token
    # generate a token that is 32 characters long and url safe
    self.token = SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    # default expiration is 7 days
    self.expires_at = 7.days.from_now unless expires_at.present?
  end

  def encryption_key
    # In prod we will want to store this in Rails credentials
    # or in an environment variable
    Rails.application.credentials.secret_key_base[0, 32]
  end
end
