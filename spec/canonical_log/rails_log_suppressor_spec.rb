# frozen_string_literal: true

RSpec.describe CanonicalLog::RailsLogSuppressor do
  describe '.suppress!' do
    let(:ac_subscriber) do
      instance_double('ActionController::LogSubscriber', class: double(name: 'ActionController::LogSubscriber'))
    end
    let(:av_subscriber) do
      instance_double('ActionView::LogSubscriber', class: double(name: 'ActionView::LogSubscriber'))
    end
    let(:other_subscriber) do
      instance_double('SomeOtherSubscriber', class: double(name: 'SomeOther::LogSubscriber'))
    end

    before do
      allow(ActiveSupport::LogSubscriber).to receive(:log_subscribers).and_return(subscribers)
    end

    context 'with Rails subscribers' do
      let(:subscribers) { [ac_subscriber, av_subscriber, other_subscriber] }

      it 'sets logger to null on ActionController::LogSubscriber' do
        expect(ac_subscriber).to receive(:logger=).with(an_instance_of(Logger))
        expect(av_subscriber).to receive(:logger=).with(an_instance_of(Logger))
        described_class.suppress!
      end

      it 'does not modify non-Rails subscribers' do
        allow(ac_subscriber).to receive(:logger=)
        allow(av_subscriber).to receive(:logger=)
        expect(other_subscriber).not_to receive(:logger=)
        described_class.suppress!
      end
    end

    context 'with no subscribers' do
      let(:subscribers) { [] }

      it 'does not raise' do
        expect { described_class.suppress! }.not_to raise_error
      end
    end
  end
end
