# frozen_string_literal: true

RSpec.describe CanonicalLog::Subscribers::ActiveSupportCache do
  before { CanonicalLog::Context.init! }

  def make_notification(name: 'cache_read.active_support', hit: nil, duration: 0.002)
    start_time = Time.now
    end_time = start_time + duration
    payload = {}
    payload[:hit] = hit unless hit.nil?
    ActiveSupport::Notifications::Event.new(
      name,
      start_time, end_time, 'unique-id',
      payload
    )
  end

  describe '.handle' do
    it 'increments cache_read_count on cache_read events' do
      described_class.handle(make_notification(hit: true))
      described_class.handle(make_notification(hit: false))
      expect(CanonicalLog::Context.current.to_h[:cache_read_count]).to eq(2)
    end

    it 'tracks hits separately' do
      described_class.handle(make_notification(hit: true))
      described_class.handle(make_notification(hit: true))
      described_class.handle(make_notification(hit: false))
      expect(CanonicalLog::Context.current.to_h[:cache_hit_count]).to eq(2)
    end

    it 'tracks misses separately' do
      described_class.handle(make_notification(hit: false))
      described_class.handle(make_notification(hit: true))
      expect(CanonicalLog::Context.current.to_h[:cache_miss_count]).to eq(1)
    end

    it 'increments cache_write_count on cache_write events' do
      described_class.handle(make_notification(name: 'cache_write.active_support'))
      described_class.handle(make_notification(name: 'cache_write.active_support'))
      expect(CanonicalLog::Context.current.to_h[:cache_write_count]).to eq(2)
    end

    it 'tracks cache_fetch_hit as a read hit' do
      described_class.handle(make_notification(name: 'cache_fetch_hit.active_support'))
      expect(CanonicalLog::Context.current.to_h[:cache_read_count]).to eq(1)
      expect(CanonicalLog::Context.current.to_h[:cache_hit_count]).to eq(1)
    end

    it 'accumulates cache_total_time_ms' do
      described_class.handle(make_notification(duration: 0.010))
      described_class.handle(make_notification(duration: 0.020))
      total = CanonicalLog::Context.current.to_h[:cache_total_time_ms]
      expect(total).to be_within(1.0).of(30.0)
    end

    it 'rounds cache_total_time_ms' do
      described_class.handle(make_notification(duration: 0.0123456))
      total = CanonicalLog::Context.current.to_h[:cache_total_time_ms]
      expect(total).to eq(total.round(2))
    end

    it 'does nothing when no current event' do
      CanonicalLog::Context.clear!
      expect { described_class.handle(make_notification) }.not_to raise_error
    end

    it 'does nothing when disabled' do
      CanonicalLog.configure { |c| c.enabled = false }
      described_class.handle(make_notification(hit: true))
      expect(CanonicalLog::Context.current.to_h[:cache_read_count]).to be_nil
    end
  end
end
