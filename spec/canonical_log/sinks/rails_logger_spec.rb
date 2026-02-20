# frozen_string_literal: true

RSpec.describe CanonicalLog::Sinks::RailsLogger do
  subject(:sink) { described_class.new }

  describe '#write' do
    it 'delegates to Rails.logger.info' do
      logger = instance_double(Logger)
      allow(logger).to receive(:info)

      rails_module = double('Rails', logger: logger)
      stub_const('Rails', rails_module)

      sink.write('{"test":true}')
      expect(logger).to have_received(:info).with('{"test":true}')
    end
  end
end
