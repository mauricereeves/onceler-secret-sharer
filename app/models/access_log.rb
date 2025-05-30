class AccessLog < ApplicationRecord
  belongs_to :secret

  validates :ip_address, presence: true
  validates :user_agent, presence: true
  validates :action, presence: true
  validates :accessed_at, presence: true

  scope :recent, -> { order(accessed_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
end
