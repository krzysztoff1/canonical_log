# frozen_string_literal: true

RSpec.describe CanonicalLog::Sampling do
  let(:config) { CanonicalLog::Configuration.new }

  describe '.default' do
    it 'returns true for 500 status' do
      expect(described_class.default({ http_status: 500 }, config)).to be true
    end

    it 'returns true for 503 status' do
      expect(described_class.default({ http_status: 503 }, config)).to be true
    end

    it 'returns true when error key is present regardless of status' do
      event = { http_status: 200, error: { class: 'RuntimeError', message: 'boom' } }
      expect(described_class.default(event, config)).to be true
    end

    it 'returns true for slow requests at threshold' do
      event = { http_status: 200, duration_ms: config.slow_request_threshold_ms }
      expect(described_class.default(event, config)).to be true
    end

    it 'returns true for slow requests above threshold' do
      event = { http_status: 200, duration_ms: config.slow_request_threshold_ms + 100 }
      expect(described_class.default(event, config)).to be true
    end

    it 'falls through to random sampling for normal requests' do
      config.sample_rate = 1.0
      event = { http_status: 200, duration_ms: 10 }
      expect(described_class.default(event, config)).to be true
    end

    it 'always rejects when sample_rate is 0.0' do
      config.sample_rate = 0.0
      event = { http_status: 200, duration_ms: 10 }
      expect(described_class.default(event, config)).to be false
    end

    it 'treats missing http_status as 0' do
      config.sample_rate = 0.0
      expect(described_class.default({}, config)).to be false
    end

    it 'treats missing duration_ms as 0' do
      config.sample_rate = 0.0
      expect(described_class.default({ http_status: 200 }, config)).to be false
    end
  end
end
