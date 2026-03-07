# frozen_string_literal: true

RSpec.describe CanonicalLog::Configuration do
  subject(:config) { described_class.new }

  describe 'defaults' do
    it 'sets sinks to :auto' do
      expect(config.sinks).to eq(:auto)
    end

    it 'has default param filter keys' do
      expect(config.param_filter_keys).to include(
        'password', 'password_confirmation', 'token', 'secret', 'secret_key',
        'api_key', 'access_token', 'credit_card', 'card_number', 'cvv', 'ssn', 'authorization'
      )
    end

    it 'has a default slow query threshold' do
      expect(config.slow_query_threshold_ms).to eq(100.0)
    end

    it 'has nil user_context' do
      expect(config.user_context).to be_nil
    end

    it 'has nil before_emit' do
      expect(config.before_emit).to be_nil
    end

    it 'has empty ignored_paths' do
      expect(config.ignored_paths).to eq([])
    end

    it 'has default sample_rate of 1.0' do
      expect(config.sample_rate).to eq(1.0)
    end

    it 'has default slow_request_threshold_ms of 2000.0' do
      expect(config.slow_request_threshold_ms).to eq(2000.0)
    end

    it 'has nil sampling' do
      expect(config.sampling).to be_nil
    end

    it 'defaults enabled to true when Rails is not defined' do
      expect(config.enabled).to be true
    end

    it 'defaults enabled to false in non-production Rails env' do
      rails = double('Rails', env: ActiveSupport::StringInquirer.new('development'))
      stub_const('Rails', rails)
      expect(described_class.new.enabled).to be false
    end

    it 'defaults enabled to true in production Rails env' do
      rails = double('Rails', env: ActiveSupport::StringInquirer.new('production'))
      stub_const('Rails', rails)
      expect(described_class.new.enabled).to be true
    end

    it 'has suppress_rails_logging false by default' do
      expect(config.suppress_rails_logging).to be false
    end

    it 'has format :json by default' do
      expect(config.format).to eq(:json)
    end

    it 'has pretty false by default (backward compat)' do
      expect(config.pretty?).to be false
    end

    it 'has filter_sql_literals true by default' do
      expect(config.filter_sql_literals).to be true
    end

    it 'has filter_query_string true by default' do
      expect(config.filter_query_string).to be true
    end

    it 'has nil log_level_resolver by default' do
      expect(config.log_level_resolver).to be_nil
    end

    it 'has empty default_fields by default' do
      expect(config.default_fields).to eq({})
    end

    it 'has error_backtrace_lines defaulting to 5' do
      expect(config.error_backtrace_lines).to eq(5)
    end
  end

  describe '#resolved_sinks' do
    it 'returns Stdout when sinks is :auto and Rails is not defined' do
      sinks = config.resolved_sinks
      expect(sinks.first).to be_a(CanonicalLog::Sinks::Stdout)
    end

    it 'wraps a single sink in an array' do
      sink = CanonicalLog::Sinks::Stdout.new
      config.sinks = sink
      expect(config.resolved_sinks).to eq([sink])
    end

    it 'returns an array as-is' do
      sinks = [CanonicalLog::Sinks::Stdout.new]
      config.sinks = sinks
      expect(config.resolved_sinks).to eq(sinks)
    end
  end

  describe '#should_sample?' do
    it 'always returns true when sample_rate >= 1.0' do
      config.sample_rate = 1.0
      expect(config.should_sample?({ http_status: 200 })).to be true
    end

    it 'does not call Sampling.sample? when sample_rate >= 1.0' do
      config.sample_rate = 1.0
      expect(CanonicalLog::Sampling).not_to receive(:sample?)
      config.should_sample?({ http_status: 200 })
    end

    it 'delegates to Sampling.sample? when sample_rate < 1.0' do
      config.sample_rate = 0.5
      expect(CanonicalLog::Sampling).to receive(:sample?).with({ http_status: 200 }, config).and_return(true)
      expect(config.should_sample?({ http_status: 200 })).to be true
    end

    it 'returns true for 5xx even with sample_rate 0.0' do
      config.sample_rate = 0.0
      expect(config.should_sample?({ http_status: 500 })).to be true
    end

    it 'uses custom sampling proc when set' do
      config.sampling = ->(event_hash, _cfg) { event_hash[:keep] == true }
      expect(config.should_sample?({ keep: true })).to be true
      expect(config.should_sample?({ keep: false })).to be false
    end

    it 'passes event_hash and config to custom sampling proc' do
      config.sampling = lambda { |event_hash, cfg|
        expect(event_hash).to eq({ test: true })
        expect(cfg).to be(config)
        true
      }
      config.should_sample?({ test: true })
    end

    it 'custom sampling overrides sample_rate' do
      config.sample_rate = 0.0
      config.sampling = ->(_event_hash, _cfg) { true }
      expect(config.should_sample?({ http_status: 200 })).to be true
    end
  end

  describe '#resolve_log_level' do
    it 'returns :error for status >= 500' do
      expect(config.resolve_log_level({ http_status: 500 })).to eq(:error)
      expect(config.resolve_log_level({ http_status: 503 })).to eq(:error)
    end

    it 'returns :warn for status >= 400' do
      expect(config.resolve_log_level({ http_status: 404 })).to eq(:warn)
      expect(config.resolve_log_level({ http_status: 422 })).to eq(:warn)
    end

    it 'returns :info for status < 400' do
      expect(config.resolve_log_level({ http_status: 200 })).to eq(:info)
      expect(config.resolve_log_level({ http_status: 301 })).to eq(:info)
    end

    it 'returns :error when error field is present regardless of status' do
      expect(config.resolve_log_level({ http_status: 200, error: { class: 'RuntimeError' } })).to eq(:error)
    end

    it 'uses custom log_level_resolver when set' do
      config.log_level_resolver = ->(_event_hash) { :debug }
      expect(config.resolve_log_level({ http_status: 500 })).to eq(:debug)
    end

    it 'passes event_hash to custom resolver' do
      config.log_level_resolver = ->(event_hash) { event_hash[:http_status] >= 500 ? :fatal : :info }
      expect(config.resolve_log_level({ http_status: 500 })).to eq(:fatal)
      expect(config.resolve_log_level({ http_status: 200 })).to eq(:info)
    end
  end

  describe 'DSL' do
    it 'configures via block' do
      CanonicalLog.configure do |c|
        c.slow_query_threshold_ms = 50.0
        c.ignored_paths = ['/health']
      end

      expect(CanonicalLog.configuration.slow_query_threshold_ms).to eq(50.0)
      expect(CanonicalLog.configuration.ignored_paths).to eq(['/health'])
    end
  end
end
