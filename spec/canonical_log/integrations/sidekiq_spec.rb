# frozen_string_literal: true

require 'canonical_log/integrations/sidekiq'

RSpec.describe CanonicalLog::Integrations::Sidekiq do
  subject(:middleware) { described_class.new }

  let(:sink) { instance_double(CanonicalLog::Sinks::Base) }
  let(:job_instance) { double('job') }
  let(:msg) { { 'class' => 'HardWorker', 'jid' => 'abc123' } }
  let(:queue) { 'default' }

  before do
    allow(sink).to receive(:write)
    CanonicalLog.configure { |c| c.sinks = [sink] }
  end

  describe '#call' do
    it 'yields to the block' do
      called = false
      middleware.call(job_instance, msg, queue) { called = true }
      expect(called).to be true
    end

    it 'emits a log line with job details' do
      middleware.call(job_instance, msg, queue) { nil }
      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed['job_class']).to eq('HardWorker')
        expect(parsed['queue']).to eq('default')
        expect(parsed['jid']).to eq('abc123')
      end
    end

    it 'captures errors and re-raises' do
      expect do
        middleware.call(job_instance, msg, queue) { raise 'job failed' }
      end.to raise_error(RuntimeError, 'job failed')

      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed['error_class']).to eq('RuntimeError')
        expect(parsed['error_message']).to eq('job failed')
      end
    end

    it 'clears context after job' do
      middleware.call(job_instance, msg, queue) { nil }
      expect(CanonicalLog::Context.current).to be_nil
    end

    it 'calls before_emit hook before writing' do
      hook_called = false
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.before_emit = ->(_event) { hook_called = true }
      end

      middleware.call(job_instance, msg, queue) { nil }
      expect(hook_called).to be true
    end

    it 'always emits (bypasses should_sample?)' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.sampling = ->(_event_hash, _config) { false }
      end

      middleware.call(job_instance, msg, queue) { nil }
      expect(sink).to have_received(:write)
    end

    it 'clears context even on error' do
      begin
        middleware.call(job_instance, msg, queue) { raise 'boom' }
      rescue StandardError
        nil
      end
      expect(CanonicalLog::Context.current).to be_nil
    end
  end
end
