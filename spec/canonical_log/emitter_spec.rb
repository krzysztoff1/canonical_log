# frozen_string_literal: true

RSpec.describe CanonicalLog::Emitter do
  let(:sink) { instance_double(CanonicalLog::Sinks::Base) }
  let(:event) { CanonicalLog::Event.new }

  before do
    allow(sink).to receive(:write)
    CanonicalLog.configure { |c| c.sinks = [sink] }
    event.add(http_method: 'GET', path: '/orders', http_status: 200)
  end

  describe '.emit!' do
    it 'calls before_emit hook before emitting' do
      called = false
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.before_emit = ->(_event) { called = true }
      end

      described_class.emit!(event)
      expect(called).to be true
    end

    it 'merges default_fields and serializes to JSON' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.default_fields = { service: 'my-app' }
      end

      described_class.emit!(event)
      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed['service']).to eq('my-app')
        expect(parsed['http_method']).to eq('GET')
      end
    end

    it 'skips emit when should_sample? returns false' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.sampling = ->(_event_hash, _config) { false }
      end

      described_class.emit!(event)
      expect(sink).not_to have_received(:write)
    end

    it 'builds default message from http_method, path, http_status' do
      described_class.emit!(event)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['message']).to eq('GET /orders 200')
      end
    end

    it 'does not overwrite existing message' do
      event.set(:message, 'custom message')
      described_class.emit!(event)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['message']).to eq('custom message')
      end
    end

    it 'rescues sink errors without crashing' do
      allow(sink).to receive(:write).and_raise(StandardError, 'sink broken')
      expect { described_class.emit!(event) }.not_to raise_error
    end

    it 'rescues emit errors without crashing' do
      allow(CanonicalLog.configuration).to receive(:default_fields).and_raise(StandardError, 'bad config')
      expect { described_class.emit!(event) }.not_to raise_error
    end

    it 'uses pretty formatter when config.pretty is true' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.pretty = true
      end

      described_class.emit!(event)
      expect(sink).to have_received(:write) do |json|
        expect(json).to include("\e[")
        expect(json).to include("\n")
      end
    end
  end
end
