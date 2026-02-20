# frozen_string_literal: true

RSpec.describe CanonicalLog::Event do
  subject(:event) { described_class.new }

  describe '#add' do
    it 'merges fields into the event' do
      event.add(user_id: 42, role: 'admin')
      expect(event.to_h).to include(user_id: 42, role: 'admin')
    end

    it 'overwrites existing keys' do
      event.add(status: 'pending')
      event.add(status: 'complete')
      expect(event.to_h[:status]).to eq('complete')
    end
  end

  describe '#set' do
    it 'sets a single field' do
      event.set(:checkout_step, 'payment')
      expect(event.to_h[:checkout_step]).to eq('payment')
    end

    it 'converts string keys to symbols' do
      event.set('name', 'test')
      expect(event.to_h[:name]).to eq('test')
    end
  end

  describe '#increment' do
    it 'increments from zero' do
      event.increment(:api_calls)
      expect(event.to_h[:api_calls]).to eq(1)
    end

    it 'increments by custom amount' do
      event.increment(:bytes, 100)
      event.increment(:bytes, 50)
      expect(event.to_h[:bytes]).to eq(150)
    end
  end

  describe '#append' do
    it 'creates an array and appends' do
      event.append(:tags, 'important')
      event.append(:tags, 'urgent')
      expect(event.to_h[:tags]).to eq(%w[important urgent])
    end
  end

  describe '#duration_ms' do
    it 'returns elapsed time in milliseconds' do
      e = described_class.new
      sleep 0.05
      expect(e.duration_ms).to be >= 10.0
    end
  end

  describe '#to_h' do
    it 'includes timestamp and duration_ms' do
      hash = event.to_h
      expect(hash).to have_key(:timestamp)
      expect(hash).to have_key(:duration_ms)
    end

    it 'returns an ISO8601 timestamp' do
      expect(event.to_h[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end
  end

  describe '#to_json' do
    it 'returns valid JSON' do
      event.add(test: true)
      parsed = JSON.parse(event.to_json)
      expect(parsed['test']).to be true
    end
  end

  describe '#context' do
    it 'adds categorized data for a valid category' do
      event.context(:user, id: 123, tier: 'premium')
      expect(event.to_h[:user]).to eq(id: 123, tier: 'premium')
    end

    it 'raises ArgumentError for invalid category' do
      expect { event.context(:invalid, data: 1) }.to raise_error(ArgumentError, /Unknown category/)
    end

    it 'merges multiple calls to the same category' do
      event.context(:user, id: 123)
      event.context(:user, tier: 'premium')
      expect(event.to_h[:user]).to eq(id: 123, tier: 'premium')
    end
  end

  describe '#add_error' do
    it 'records error class and message' do
      error = RuntimeError.new('boom')
      event.add_error(error)
      expect(event.to_h[:error]).to eq(class: 'RuntimeError', message: 'boom')
    end

    it 'merges metadata into error hash' do
      error = RuntimeError.new('boom')
      event.add_error(error, context: 'checkout')
      expect(event.to_h[:error]).to include(class: 'RuntimeError', message: 'boom', context: 'checkout')
    end

    it 'allows metadata to override base keys' do
      error = RuntimeError.new('boom')
      event.add_error(error, message: 'custom message')
      expect(event.to_h[:error][:message]).to eq('custom message')
    end
  end

  describe 'thread safety' do
    it 'handles concurrent increments' do
      threads = 10.times.map do
        Thread.new { 100.times { event.increment(:counter) } }
      end
      threads.each(&:join)
      expect(event.to_h[:counter]).to eq(1000)
    end
  end
end
