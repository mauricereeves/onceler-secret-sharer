require "rails_helper"

RSpec.describe Secret, type: :model do
  # ASSOCIATIONS
  describe "associations" do
    it { should have_many(:access_logs).dependent(:destroy) }
  end

  # VALIDATIONS
  describe "validations" do
    subject { build(:secret) }
    it { should validate_presence_of(:token) }
    it { should validate_uniqueness_of(:token).case_insensitive }
    it { should validate_presence_of(:encrypted_content) }
    it { should validate_presence_of(:content_iv) }
    it { should validate_presence_of(:max_views) }
    it { should validate_numericality_of(:max_views).is_greater_than(0) }
  end

  # CALLBACKS
  describe "callbacks" do
    it "generates a token before validation on create" do
      secret = build(:secret, token: nil)
      expect(secret.token).to be_nil
      secret.valid?
      expect(secret.token).to be_present
      expect(secret.token.length).to be > 20
    end

    it 'sets expiration date before validation on create' do
      secret = build(:secret, expires_at: nil)
      expect(secret.expires_at).to be_nil
      secret.valid?
      expect(secret.expires_at).to be_within(1.minute).of(7.days.from_now)
    end

    it 'does not override existing expiration date' do
      custom_expiry = 1.day.from_now
      secret = build(:secret, expires_at: custom_expiry)
      secret.valid?
      expect(secret.expires_at).to be_within(1.second).of(custom_expiry)
    end
  end

  # SCOPES
  describe 'scopes' do
    let!(:active_secret) { create(:secret) }
    let!(:expired_secret) { create(:expired_secret) }
    let!(:revoked_secret) { create(:revoked_secret) }

    describe '.active' do
      it 'returns only non-expired, non-revoked secrets' do
        expect(Secret.active).to include(active_secret)
        expect(Secret.active).not_to include(expired_secret)
        expect(Secret.active).not_to include(revoked_secret)
      end
    end

    describe '.expired' do
      it 'returns expired or revoked secrets' do
        expect(Secret.expired).to include(expired_secret)
        expect(Secret.expired).to include(revoked_secret)
        expect(Secret.expired).not_to include(active_secret)
      end
    end

    describe '.find_active' do
      it 'finds active secret by token' do
        found_secret = Secret.find_active(active_secret.token)
        expect(found_secret).to eq(active_secret)
      end

      it 'does not find expired secret' do
        found_secret = Secret.find_active(expired_secret.token)
        expect(found_secret).to be_nil
      end

      it 'does not find revoked secret' do
        found_secret = Secret.find_active(revoked_secret.token)
        expect(found_secret).to be_nil
      end
    end
  end

  # INSTANCE METHODS
  describe '#expired?' do
    it 'returns true for expired secret' do
      secret = create(:expired_secret)
      expect(secret.expired?).to be true
    end

    it 'returns true for revoked secret' do
      secret = create(:revoked_secret)
      expect(secret.expired?).to be true
    end

    it 'returns false for active secret' do
      secret = create(:secret)
      expect(secret.expired?).to be false
    end
  end

  describe '#can_be_viewed?' do
    it 'returns true for unviewed active secret' do
      secret = create(:secret)
      expect(secret.can_be_viewed?).to be true
    end

    it 'returns false for expired secret' do
      secret = create(:expired_secret)
      expect(secret.can_be_viewed?).to be false
    end

    it 'returns false for secret at max views' do
      secret = create(:viewed_secret)
      expect(secret.can_be_viewed?).to be false
    end

    it 'returns false for revoked secret' do
      secret = create(:revoked_secret)
      expect(secret.can_be_viewed?).to be false
    end
  end

  # ENCRYPTION/DECRYPTION
  describe 'encryption' do
    let(:plain_text) { "This is my secret password: admin123!" }
    let(:secret) { build(:secret) }

    it 'encrypts content when setting' do
      secret.content = plain_text
      expect(secret.encrypted_content).to be_present
      expect(secret.content_iv).to be_present
      expect(secret.encrypted_content).not_to eq(plain_text)
    end

    it 'decrypts content when reading' do
      secret.content = plain_text
      expect(secret.content).to eq(plain_text)
    end

    it 'handles UTF-8 characters correctly' do
      unicode_text = "Secret émojis: 🔐🔑 and üñíçødé"
      secret.content = unicode_text
      expect(secret.content).to eq(unicode_text)
    end

    it 'returns nil for tampered content' do
      secret.content = plain_text
      # Tamper with the encrypted content
      secret.encrypted_content = "tampered_content"
      expect(secret.content).to be_nil
    end

    it 'uses different IVs for same content' do
      secret1 = build(:secret)
      secret2 = build(:secret)

      secret1.content = plain_text
      secret2.content = plain_text

      expect(secret1.content_iv).not_to eq(secret2.content_iv)
      expect(secret1.encrypted_content).not_to eq(secret2.encrypted_content)
    end
  end

  # VIEWING AND REVOCATION
  describe '#mark_as_viewed!' do
    let(:secret) { create(:secret_with_content, max_views: 2) }
    let(:ip) { '192.168.1.1' }
    let(:user_agent) { 'Test Browser' }

    it 'increments view count' do
      expect {
        secret.mark_as_viewed!(ip, user_agent)
      }.to change(secret, :view_count).from(0).to(1)
    end

    it 'creates access log entry' do
      expect {
        secret.mark_as_viewed!(ip, user_agent)
      }.to change(secret.access_logs, :count).by(1)

      log = secret.access_logs.last
      expect(log.action).to eq('viewed')
      expect(log.ip_address).to eq(ip)
      expect(log.user_agent).to eq(user_agent)
    end

    it 'revokes secret when max views reached' do
      secret.update!(view_count: 1) # At 1 view already

      expect {
        secret.mark_as_viewed!(ip, user_agent)
      }.to change(secret, :revoked).from(false).to(true)

      log = secret.access_logs.last
      expect(log.action).to eq('revoked')
      expect(log.details).to include('Secret revoked after 2 views')
    end
  end

  describe '#log_access' do
    let(:secret) { create(:secret) }

    it 'creates access log with correct attributes' do
      Timecop.freeze do
        secret.log_access('test_action', '1.1.1.1', 'Chrome', 'Test details')

        log = secret.access_logs.last
        expect(log.action).to eq('test_action')
        expect(log.ip_address).to eq('1.1.1.1')
        expect(log.user_agent).to eq('Chrome')
        expect(log.details).to eq('Test details')
        expect(log.accessed_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe '#public_url' do
    let(:secret) { create(:secret) }

    it 'generates correct URL' do
      allow(Rails.application.routes.url_helpers).to receive(:view_secret_url).and_return("https://example.com/s/#{secret.token}")

      expect(secret.public_url).to eq("https://example.com/s/#{secret.token}")
    end
  end

  # EDGE CASES
  describe 'edge cases' do
    it 'handles empty content gracefully' do
      secret = build(:secret)
      secret.content = ""
      expect(secret.encrypted_content).to be_blank
      expect(secret.content_iv).to be_blank
    end

    it 'handles nil content gracefully' do
      secret = build(:secret)
      secret.content = nil
      expect(secret.encrypted_content).to be_blank
      expect(secret.content_iv).to be_blank
    end

    it 'generates unique tokens' do
      tokens = 100.times.map { build(:secret).tap(&:valid?).token }
      expect(tokens.uniq.length).to eq(100)
    end

    it 'handles very long content' do
      long_text = "A" * 10_000
      secret = build(:secret)
      secret.content = long_text
      expect(secret.content).to eq(long_text)
    end
  end
end
