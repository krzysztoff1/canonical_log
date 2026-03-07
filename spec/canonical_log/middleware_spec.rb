# frozen_string_literal: true

require 'rack'

RSpec.describe CanonicalLog::Middleware do
  let(:sink) { instance_double(CanonicalLog::Sinks::Base) }
  let(:app_response) { [200, { 'Content-Type' => 'text/plain' }, ['OK']] }
  let(:inner_app) { ->(_env) { app_response } }
  let(:middleware) { described_class.new(inner_app) }
  let(:env) do
    {
      'REQUEST_METHOD' => 'GET',
      'PATH_INFO' => '/orders',
      'REMOTE_ADDR' => '127.0.0.1',
    }
  end

  before do
    allow(sink).to receive(:write)
    CanonicalLog.configure { |c| c.sinks = [sink] }
  end

  describe 'dynamic log level' do
    it 'sets level to "info" for status 200' do
      middleware.call(env)
      expect(sink).to have_received(:write).with(anything, level: :info) do |json|
        expect(JSON.parse(json)['level']).to eq('info')
      end
    end

    it 'sets level to "warn" for status 404' do
      app = ->(_env) { [404, {}, ['Not Found']] }
      mw = described_class.new(app)
      mw.call(env)
      expect(sink).to have_received(:write).with(anything, level: :warn) do |json|
        expect(JSON.parse(json)['level']).to eq('warn')
      end
    end

    it 'sets level to "error" for status 500' do
      app = ->(_env) { [500, {}, ['Error']] }
      mw = described_class.new(app)
      mw.call(env)
      expect(sink).to have_received(:write).with(anything, level: :error) do |json|
        expect(JSON.parse(json)['level']).to eq('error')
      end
    end

    it 'sets level to "error" when error field is present regardless of status' do
      app = ->(_env) { raise 'boom' }
      mw = described_class.new(app)
      begin
        mw.call(env)
      rescue StandardError
        nil
      end
      expect(sink).to have_received(:write).with(anything, level: :error) do |json|
        expect(JSON.parse(json)['level']).to eq('error')
      end
    end

    it 'uses custom log_level_resolver when configured' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.log_level_resolver = ->(_event_hash) { :debug }
      end
      middleware.call(env)
      expect(sink).to have_received(:write).with(anything, level: :debug) do |json|
        expect(JSON.parse(json)['level']).to eq('debug')
      end
    end
  end

  describe 'success path' do
    it 'returns the app response' do
      status, _, body = middleware.call(env)
      expect(status).to eq(200)
      expect(body).to eq(['OK'])
    end

    it 'emits a JSON log line' do
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed['http_method']).to eq('GET')
        expect(parsed['path']).to eq('/orders')
        expect(parsed['http_status']).to eq(200)
        expect(parsed['duration_ms']).to be_a(Numeric)
      end
    end

    it 'clears context after request' do
      middleware.call(env)
      expect(CanonicalLog::Context.current).to be_nil
    end
  end

  describe 'error path' do
    let(:inner_app) { ->(_env) { raise 'boom' } }

    it 're-raises the exception' do
      expect { middleware.call(env) }.to raise_error(RuntimeError, 'boom')
    end

    it 'captures error details before re-raising' do
      begin
        middleware.call(env)
      rescue StandardError
        nil
      end
      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed['error']['class']).to eq('RuntimeError')
        expect(parsed['error']['message']).to eq('boom')
        expect(parsed['http_status']).to eq(500)
      end
    end

    it 'clears context even on error' do
      begin
        middleware.call(env)
      rescue StandardError
        nil
      end
      expect(CanonicalLog::Context.current).to be_nil
    end
  end

  describe 'ignored paths' do
    before do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.ignored_paths = ['/health', %r{\A/assets}]
      end
    end

    it 'skips logging for string-matched paths' do
      env['PATH_INFO'] = '/health'
      middleware.call(env)
      expect(sink).not_to have_received(:write)
    end

    it 'skips logging for regexp-matched paths' do
      env['PATH_INFO'] = '/assets/app.js'
      middleware.call(env)
      expect(sink).not_to have_received(:write)
    end

    it 'still logs non-ignored paths' do
      env['PATH_INFO'] = '/orders'
      middleware.call(env)
      expect(sink).to have_received(:write)
    end
  end

  describe 'before_emit hook' do
    it 'calls the hook before emitting' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.before_emit = ->(event) { event.set(:custom, 'injected') }
      end

      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['custom']).to eq('injected')
      end
    end
  end

  describe 'request field seeding' do
    it 'filters sensitive params from query_string by default' do
      env['QUERY_STRING'] = 'page=1&api_key=secret123&sort=name'
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        qs = JSON.parse(json)['query_string']
        expect(qs).to include('page=1')
        expect(qs).to include('sort=name')
        expect(qs).to include('api_key=%5BFILTERED%5D')
        expect(qs).not_to include('secret123')
      end
    end

    it 'preserves raw query_string when filter_query_string is false' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.filter_query_string = false
      end
      env['QUERY_STRING'] = 'page=1&api_key=secret123'
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['query_string']).to eq('page=1&api_key=secret123')
      end
    end

    it 'handles malformed query strings gracefully' do
      env['QUERY_STRING'] = "bad\xFF\xFEquery"
      expect { middleware.call(env) }.not_to raise_error
    end

    it 'sets query_string to nil when empty' do
      env['QUERY_STRING'] = ''
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['query_string']).to be_nil
      end
    end

    it 'sets query_string to nil when absent' do
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['query_string']).to be_nil
      end
    end

    it 'seeds user_agent from env' do
      env['HTTP_USER_AGENT'] = 'Mozilla/5.0'
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['user_agent']).to eq('Mozilla/5.0')
      end
    end

    it 'seeds content_type from env' do
      env['CONTENT_TYPE'] = 'application/json'
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['content_type']).to eq('application/json')
      end
    end

    it 'prefers HTTP_X_FORWARDED_FOR for remote_ip' do
      env['REMOTE_ADDR'] = '10.0.0.1'
      env['HTTP_X_FORWARDED_FOR'] = '203.0.113.50'
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['remote_ip']).to eq('203.0.113.50')
      end
    end

    it 'falls back to REMOTE_ADDR for remote_ip' do
      env['REMOTE_ADDR'] = '10.0.0.1'
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['remote_ip']).to eq('10.0.0.1')
      end
    end

    it 'uses action_dispatch.request_id when present' do
      env['action_dispatch.request_id'] = 'dispatch-uuid'
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['request_id']).to eq('dispatch-uuid')
      end
    end

    it 'falls back to HTTP_X_REQUEST_ID' do
      env['HTTP_X_REQUEST_ID'] = 'header-uuid'
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['request_id']).to eq('header-uuid')
      end
    end

    it 'generates a UUID when no request_id source is available' do
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        request_id = JSON.parse(json)['request_id']
        expect(request_id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      end
    end
  end

  describe 'user context enrichment' do
    it 'merges hash from custom user_context proc' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.user_context = ->(_env) { { user_id: 42, role: 'admin' } }
      end

      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed['user_id']).to eq(42)
        expect(parsed['role']).to eq('admin')
      end
    end

    it 'ignores non-hash return from user_context' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.user_context = ->(_env) { 'not a hash' }
      end

      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed).not_to have_key('user_id')
      end
    end

    it 'does not crash the request when user_context raises' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.user_context = ->(_env) { raise 'user lookup failed' }
      end

      expect { middleware.call(env) }.not_to raise_error
      expect(sink).to have_received(:write)
    end
  end

  describe 'sampling integration' do
    it 'does not emit when should_sample? returns false' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.sampling = ->(_event_hash, _config) { false }
      end

      middleware.call(env)
      expect(sink).not_to have_received(:write)
    end

    it 'emits when should_sample? returns true' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.sampling = ->(_event_hash, _config) { true }
      end

      middleware.call(env)
      expect(sink).to have_received(:write)
    end
  end

  describe 'default_fields' do
    it 'includes default_fields in emitted JSON' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.default_fields = { service: 'my-app', environment: 'production' }
      end

      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed['service']).to eq('my-app')
        expect(parsed['environment']).to eq('production')
      end
    end

    it 'event fields override default_fields' do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.default_fields = { http_method: 'DEFAULT', service: 'my-app' }
      end

      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed['http_method']).to eq('GET')
        expect(parsed['service']).to eq('my-app')
      end
    end
  end

  describe 'when disabled' do
    before do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.enabled = false
      end
    end

    it 'passes through without emitting' do
      status, _, body = middleware.call(env)
      expect(status).to eq(200)
      expect(body).to eq(['OK'])
      expect(sink).not_to have_received(:write)
    end

    it 'does not initialize context' do
      middleware.call(env)
      expect(CanonicalLog::Context.current).to be_nil
    end
  end

  describe 'pretty mode' do
    before do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.pretty = true
      end
    end

    it 'emits colorized indented JSON' do
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(json).to include("\e[")
        expect(json).to include("\n")
        stripped = json.gsub(/\e\[[0-9;]*m/, '')
        parsed = JSON.parse(stripped)
        expect(parsed['http_method']).to eq('GET')
      end
    end
  end

  describe 'logfmt mode' do
    before do
      CanonicalLog.configure do |c|
        c.sinks = [sink]
        c.format = :logfmt
      end
    end

    it 'emits logfmt key=value output' do
      middleware.call(env)
      expect(sink).to have_received(:write) do |output|
        expect(output).to include('http_method=GET')
        expect(output).to include('path=/orders')
        expect(output).to include('http_status=200')
      end
    end
  end

  describe 'OpenTelemetry trace correlation' do
    let(:span_context) do
      instance_double(
        'OpenTelemetry::Trace::SpanContext',
        valid?: true,
        hex_trace_id: 'aabbccdd11223344aabbccdd11223344',
        hex_span_id: 'aabbccdd11223344',
      )
    end
    let(:span) { instance_double('OpenTelemetry::Trace::Span', context: span_context) }

    before do
      otel_trace = Module.new do
        def self.current_span
        end
      end
      stub_const('OpenTelemetry::Trace', otel_trace)
      allow(OpenTelemetry::Trace).to receive(:current_span).and_return(span)
    end

    it 'adds trace_id and span_id when OpenTelemetry is present' do
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed['trace_id']).to eq('aabbccdd11223344aabbccdd11223344')
        expect(parsed['span_id']).to eq('aabbccdd11223344')
      end
    end

    it 'skips trace fields when span context is invalid' do
      allow(span_context).to receive(:valid?).and_return(false)
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed).not_to have_key('trace_id')
        expect(parsed).not_to have_key('span_id')
      end
    end
  end

  describe 'no OpenTelemetry' do
    it 'does not add trace fields when OpenTelemetry is not defined' do
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        parsed = JSON.parse(json)
        expect(parsed).not_to have_key('trace_id')
        expect(parsed).not_to have_key('span_id')
      end
    end
  end

  describe 'body size tracking' do
    it 'captures response_size_bytes from Content-Length header' do
      app = ->(_env) { [200, { 'Content-Length' => '1234' }, ['body']] }
      mw = described_class.new(app)
      mw.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['response_size_bytes']).to eq(1234)
      end
    end

    it 'captures request_size_bytes from CONTENT_LENGTH env' do
      env['CONTENT_LENGTH'] = '567'
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['request_size_bytes']).to eq(567)
      end
    end

    it 'sets response_size_bytes to nil when Content-Length not present' do
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['response_size_bytes']).to be_nil
      end
    end

    it 'sets request_size_bytes to nil when CONTENT_LENGTH not present' do
      middleware.call(env)
      expect(sink).to have_received(:write) do |json|
        expect(JSON.parse(json)['request_size_bytes']).to be_nil
      end
    end
  end

  describe 'sink errors' do
    it 'does not crash the request when a sink raises' do
      allow(sink).to receive(:write).and_raise(StandardError, 'sink broken')
      expect { middleware.call(env) }.not_to raise_error
    end
  end
end
