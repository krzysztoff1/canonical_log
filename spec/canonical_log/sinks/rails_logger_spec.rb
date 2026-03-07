# frozen_string_literal: true

RSpec.describe CanonicalLog::Sinks::RailsLogger do
  subject(:sink) { described_class.new }

  let(:logger) { instance_double(Logger) }

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(logger).to receive(:error)
    rails_module = double('Rails', logger: logger)
    stub_const('Rails', rails_module)
  end

  describe '#write' do
    it 'defaults to Rails.logger.info' do
      sink.write('{"test":true}')
      expect(logger).to have_received(:info).with('{"test":true}')
    end

    it 'calls Rails.logger.error when level: :error' do
      sink.write('{"test":true}', level: :error)
      expect(logger).to have_received(:error).with('{"test":true}')
    end

    it 'calls Rails.logger.warn when level: :warn' do
      sink.write('{"test":true}', level: :warn)
      expect(logger).to have_received(:warn).with('{"test":true}')
    end
  end
end
