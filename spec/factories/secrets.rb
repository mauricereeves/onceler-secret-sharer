FactoryBot.define do
  factory :secret do
    # our blessed attributes
    token { SecureRandom.urlsafe_base64(32) }
    encrypted_content { "encrypted_content_here" }
    content_iv { "iv_here" }
    expires_at { 7.days.from_now }
    created_by_ip { Faker::Internet.ip_v4_address }
    max_views { 1 }
    view_count { 0 }
    revoked { false }

    # factory that sets up the encrypted content
    factory :secret_with_content do
      transient do
        plain_content { "this is a secret message" }
      end

      after(:build) do |secret, evaluator|
        secret.content = evaluator.plain_content
      end
    end

    # factory for expiration
    factory :expired_secret do
      expires_at { 1.day.ago }
    end

    # factory for revoked secrets
    factory :revoked_secret do
      revoked { true }
    end

    # factory for secrets at max views
    factory :viewed_secret do
      view_count { 1 }
      max_views { 1 }
    end
  end
end
