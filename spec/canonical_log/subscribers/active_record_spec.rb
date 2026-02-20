# frozen_string_literal: true

RSpec.describe CanonicalLog::Subscribers::ActiveRecord do
  before { CanonicalLog::Context.init! }

  def make_notification(name: 'User Load', sql: 'SELECT * FROM users', duration: 0.005)
    start_time = Time.now
    end_time = start_time + duration
    ActiveSupport::Notifications::Event.new(
      'sql.active_record',
      start_time, end_time, 'unique-id',
      { name: name, sql: sql }
    )
  end

  describe '.handle' do
    it 'increments db_query_count' do
      described_class.handle(make_notification)
      described_class.handle(make_notification)
      expect(CanonicalLog::Context.current.to_h[:db_query_count]).to eq(2)
    end

    it 'accumulates db_total_time_ms' do
      described_class.handle(make_notification(duration: 0.010))
      described_class.handle(make_notification(duration: 0.020))
      total = CanonicalLog::Context.current.to_h[:db_total_time_ms]
      expect(total).to be_within(1.0).of(30.0)
    end

    it 'ignores SCHEMA queries' do
      described_class.handle(make_notification(name: 'SCHEMA'))
      expect(CanonicalLog::Context.current.to_h[:db_query_count]).to be_nil
    end

    it 'ignores CACHE queries' do
      described_class.handle(make_notification(name: 'CACHE'))
      expect(CanonicalLog::Context.current.to_h[:db_query_count]).to be_nil
    end

    it 'captures slow queries above threshold' do
      CanonicalLog.configure { |c| c.slow_query_threshold_ms = 10.0 }
      described_class.handle(make_notification(duration: 0.050, sql: 'SELECT * FROM big_table'))

      slow = CanonicalLog::Context.current.to_h[:slow_queries]
      expect(slow).to be_an(Array)
      expect(slow.first[:sql]).to include('big_table')
    end

    it 'does not capture queries below threshold' do
      CanonicalLog.configure { |c| c.slow_query_threshold_ms = 1000.0 }
      described_class.handle(make_notification(duration: 0.005))
      expect(CanonicalLog::Context.current.to_h[:slow_queries]).to be_nil
    end

    it 'includes sql, duration_ms, and name in slow query entry' do
      CanonicalLog.configure { |c| c.slow_query_threshold_ms = 10.0 }
      described_class.handle(make_notification(duration: 0.050, sql: 'SELECT 1', name: 'User Load'))

      slow = CanonicalLog::Context.current.to_h[:slow_queries].first
      expect(slow).to have_key(:sql)
      expect(slow).to have_key(:duration_ms)
      expect(slow).to have_key(:name)
      expect(slow[:name]).to eq('User Load')
    end

    it 'accumulates multiple slow queries' do
      CanonicalLog.configure { |c| c.slow_query_threshold_ms = 10.0 }
      described_class.handle(make_notification(duration: 0.050, sql: 'SELECT 1'))
      described_class.handle(make_notification(duration: 0.060, sql: 'SELECT 2'))

      slow = CanonicalLog::Context.current.to_h[:slow_queries]
      expect(slow.length).to eq(2)
    end

    it 'rounds db_total_time_ms' do
      described_class.handle(make_notification(duration: 0.0123456))
      total = CanonicalLog::Context.current.to_h[:db_total_time_ms]
      expect(total).to eq(total.round(2))
    end

    it 'does nothing when no current event' do
      CanonicalLog::Context.clear!
      expect { described_class.handle(make_notification) }.not_to raise_error
    end
  end
end
