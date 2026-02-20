# frozen_string_literal: true

RSpec.describe CanonicalLog::Subscribers::ActionController do
  before { CanonicalLog::Context.init! }

  describe '.handle' do
    let(:payload) do
      {
        controller: 'OrdersController',
        action: 'create',
        format: :json,
        params: { 'item_id' => '42', 'password' => 'secret123', 'controller' => 'orders', 'action' => 'create' },
        view_runtime: 12.345,
        db_runtime: 45.678
      }
    end

    let(:notification) do
      ActiveSupport::Notifications::Event.new(
        'process_action.action_controller',
        Time.now, Time.now + 0.1, 'unique-id', payload
      )
    end

    it 'adds controller and action' do
      described_class.handle(notification)
      event = CanonicalLog::Context.current.to_h
      expect(event[:controller]).to eq('OrdersController')
      expect(event[:action]).to eq('create')
    end

    it 'adds format' do
      described_class.handle(notification)
      expect(CanonicalLog::Context.current.to_h[:format]).to eq(:json)
    end

    it 'filters sensitive params' do
      described_class.handle(notification)
      params = CanonicalLog::Context.current.to_h[:params]
      expect(params['item_id']).to eq('42')
      expect(params['password']).to eq('[FILTERED]')
    end

    it 'excludes controller and action from params' do
      described_class.handle(notification)
      params = CanonicalLog::Context.current.to_h[:params]
      expect(params).not_to have_key('controller')
      expect(params).not_to have_key('action')
    end

    it 'adds view and db runtime' do
      described_class.handle(notification)
      event = CanonicalLog::Context.current.to_h
      expect(event[:view_runtime_ms]).to eq(12.35)
      expect(event[:db_runtime_ms]).to eq(45.68)
    end

    # user_context is now handled in the middleware, not the subscriber

    it 'filters nested params recursively' do
      payload[:params] = {
        'order' => { 'token' => 'secret-token', 'amount' => '100' },
        'controller' => 'orders',
        'action' => 'create'
      }
      notification = ActiveSupport::Notifications::Event.new(
        'process_action.action_controller',
        Time.now, Time.now + 0.1, 'unique-id', payload
      )
      described_class.handle(notification)
      params = CanonicalLog::Context.current.to_h[:params]
      expect(params['order']['token']).to eq('[FILTERED]')
      expect(params['order']['amount']).to eq('100')
    end

    it 'handles nil view_runtime gracefully' do
      payload[:view_runtime] = nil
      notification = ActiveSupport::Notifications::Event.new(
        'process_action.action_controller',
        Time.now, Time.now + 0.1, 'unique-id', payload
      )
      described_class.handle(notification)
      expect(CanonicalLog::Context.current.to_h[:view_runtime_ms]).to be_nil
    end

    it 'handles nil db_runtime gracefully' do
      payload[:db_runtime] = nil
      notification = ActiveSupport::Notifications::Event.new(
        'process_action.action_controller',
        Time.now, Time.now + 0.1, 'unique-id', payload
      )
      described_class.handle(notification)
      expect(CanonicalLog::Context.current.to_h[:db_runtime_ms]).to be_nil
    end

    it 'does nothing when no current event' do
      CanonicalLog::Context.clear!
      expect { described_class.handle(notification) }.not_to raise_error
    end
  end
end
