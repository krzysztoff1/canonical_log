# frozen_string_literal: true

RSpec.describe CanonicalLog::RailsLogSuppressor do
  describe '.suppress_log_subscribers!' do
    let(:ac_subscriber) do
      double('ActionController::LogSubscriber', class: double(name: 'ActionController::LogSubscriber'))
    end
    let(:av_subscriber) do
      double('ActionView::LogSubscriber', class: double(name: 'ActionView::LogSubscriber'))
    end
    let(:ar_subscriber) do
      double('ActiveRecord::LogSubscriber', class: double(name: 'ActiveRecord::LogSubscriber'))
    end
    let(:other_subscriber) do
      double('SomeOther::LogSubscriber', class: double(name: 'SomeOther::LogSubscriber'))
    end

    before do
      allow(ActiveSupport::LogSubscriber).to receive(:log_subscribers).and_return(subscribers)
    end

    context 'with Rails subscribers' do
      let(:subscribers) { [ac_subscriber, av_subscriber, ar_subscriber, other_subscriber] }

      it 'sets logger to null on ActionController, ActionView, and ActiveRecord subscribers' do
        expect(ac_subscriber).to receive(:logger=).with(an_instance_of(Logger))
        expect(av_subscriber).to receive(:logger=).with(an_instance_of(Logger))
        expect(ar_subscriber).to receive(:logger=).with(an_instance_of(Logger))
        described_class.suppress_log_subscribers!
      end

      it 'does not modify non-Rails subscribers' do
        allow(ac_subscriber).to receive(:logger=)
        allow(av_subscriber).to receive(:logger=)
        allow(ar_subscriber).to receive(:logger=)
        expect(other_subscriber).not_to receive(:logger=)
        described_class.suppress_log_subscribers!
      end
    end

    context 'with no subscribers' do
      let(:subscribers) { [] }

      it 'does not raise' do
        expect { described_class.suppress_log_subscribers! }.not_to raise_error
      end
    end
  end

  describe '.suppress_rack_logger!' do
    context 'when Rails::Rack::Logger is defined' do
      let(:rack_logger_class) { Class.new }

      before do
        stub_const('Rails::Rack::Logger', rack_logger_class)
      end

      it 'prepends SilentRackLogger module' do
        described_class.suppress_rack_logger!
        expect(rack_logger_class.ancestors).to include(described_class::SilentRackLogger)
      end
    end
  end

  describe '.suppress!' do
    it 'calls both suppress methods' do
      expect(described_class).to receive(:suppress_log_subscribers!)
      expect(described_class).to receive(:suppress_rack_logger!)
      described_class.suppress!
    end
  end
end
