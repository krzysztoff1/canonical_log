# frozen_string_literal: true

require 'canonical_log/integrations/error_enrichment'

RSpec.describe CanonicalLog::Integrations::ErrorEnrichment do
  before { CanonicalLog::Context.init! }

  # Simulate a minimal controller with around_action support
  let(:controller_class) do
    Class.new do
      def self.around_action(method_name)
        @around_actions ||= []
        @around_actions << method_name
      end

      def self.around_actions
        @around_actions || []
      end

      include CanonicalLog::Integrations::ErrorEnrichment

      def run_action(&block)
        action = self.class.around_actions.first
        if action
          send(action, &block)
        else
          block.call
        end
      end

      private

      def capture_errors_for_canonical_log
        yield
      rescue StandardError => e
        CanonicalLog.add(
          rescued_error_class: e.class.name,
          rescued_error_message: e.message
        )
        raise
      end
    end
  end

  it 'captures rescued exception details' do
    controller = controller_class.new
    expect do
      controller.run_action { raise ArgumentError, 'bad input' }
    end.to raise_error(ArgumentError)

    event = CanonicalLog::Context.current.to_h
    expect(event[:rescued_error_class]).to eq('ArgumentError')
    expect(event[:rescued_error_message]).to eq('bad input')
  end

  it 'does not interfere with successful actions' do
    controller = controller_class.new
    result = controller.run_action { 'success' }
    expect(result).to eq('success')
    expect(CanonicalLog::Context.current.to_h).not_to have_key(:rescued_error_class)
  end
end
