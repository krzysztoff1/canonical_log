# frozen_string_literal: true

require 'canonical_log/subscribers/active_job'

RSpec.describe CanonicalLog::Subscribers::ActiveJob do
  let(:sink) { instance_double(CanonicalLog::Sinks::Base) }

  before do
    allow(sink).to receive(:write)
    CanonicalLog.configure { |c| c.sinks = [sink] }
  end

  def build_notification(job:, exception_object: nil, duration: 150.0)
    payload = { job: job }
    payload[:exception_object] = exception_object if exception_object

    start_time = Time.now
    end_time = start_time + (duration / 1000.0)

    ActiveSupport::Notifications::Event.new(
      'perform.active_job',
      start_time, end_time, 'unique-id', payload
    )
  end

  def fake_job(attrs = {})
    double('ActiveJob',
           class: double(name: attrs.fetch(:class_name, 'SendEmailJob')),
           queue_name: attrs.fetch(:queue_name, 'default'),
           job_id: attrs.fetch(:job_id, 'job-123'),
           executions: attrs.fetch(:executions, 1),
           priority: attrs.fetch(:priority, nil))
  end

  describe '.handle' do
    it 'emits a log line with job details' do
      job = fake_job
      described_class.handle(build_notification(job: job))

      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed['job_class']).to eq('SendEmailJob')
        expect(parsed['queue']).to eq('default')
        expect(parsed['job_id']).to eq('job-123')
        expect(parsed['executions']).to eq(1)
        expect(parsed['priority']).to be_nil
      end
    end

    it 'includes duration_ms' do
      job = fake_job
      described_class.handle(build_notification(job: job, duration: 250.567))

      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed['duration_ms']).to eq(250.57)
      end
    end

    it 'captures error details from exception_object' do
      job = fake_job
      error = RuntimeError.new('something broke')
      described_class.handle(build_notification(job: job, exception_object: error))

      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed['error_class']).to eq('RuntimeError')
        expect(parsed['error_message']).to eq('something broke')
      end
    end

    it 'clears context after job completes' do
      job = fake_job
      described_class.handle(build_notification(job: job))
      expect(CanonicalLog::Context.current).to be_nil
    end

    it 'clears context even when an error occurs during emit' do
      job = fake_job
      allow(CanonicalLog::Emitter).to receive(:emit!).and_raise(StandardError, 'emit failed')

      expect { described_class.handle(build_notification(job: job)) }.to raise_error(StandardError, 'emit failed')
      expect(CanonicalLog::Context.current).to be_nil
    end

    it 'respects sampling (skips emit when should_sample? returns false)' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.sampling = ->(_event_hash, _config) { false }
      end

      job = fake_job
      described_class.handle(build_notification(job: job))
      expect(sink).not_to have_received(:write)
    end

    it 'does nothing when disabled' do
      CanonicalLog.configure { |c| c.enabled = false }
      job = fake_job
      described_class.handle(build_notification(job: job))
      expect(sink).not_to have_received(:write)
      expect(CanonicalLog::Context.current).to be_nil
    end

    it 'does not leave context from a previous HTTP request' do
      # Simulate existing HTTP context
      CanonicalLog::Context.init!
      CanonicalLog::Context.current.set(:path, '/orders')

      job = fake_job
      described_class.handle(build_notification(job: job))

      # Context should be cleared (job subscriber manages its own lifecycle)
      expect(CanonicalLog::Context.current).to be_nil
    end

    it 'calls before_emit hook' do
      hook_called = false
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.before_emit = ->(_event) { hook_called = true }
      end

      job = fake_job
      described_class.handle(build_notification(job: job))
      expect(hook_called).to be true
    end

    it 'includes priority when set' do
      job = fake_job(priority: 10)
      described_class.handle(build_notification(job: job))

      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed['priority']).to eq(10)
      end
    end
  end
end
