FactoryBot.define do
  factory :access_log do
    association :secret
    ip_address { Faker::Internet.ip_v4_address }
    user_agent { Faker::Internet.user_agent }
    action { "viewed" }
    details { nil }
    accessed_at { Time.current }

    factory :failed_access_log do
      action { "failed_attempt" }
      details { "Secret not found" }
    end

    factory :creation_log do
      action { "created" }
    end

    factory :revocation_log do
      action { "manually_revoked" }
      details { "Secret manually revoked by creator" }
    end
  end
end
