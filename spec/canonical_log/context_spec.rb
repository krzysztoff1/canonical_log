# frozen_string_literal: true

RSpec.describe CanonicalLog::Context do
  describe '.init!' do
    it 'creates a new event on the current thread' do
      described_class.init!
      expect(described_class.current).to be_a(CanonicalLog::Event)
    end
  end

  describe '.current' do
    it 'returns nil when no event is initialized' do
      described_class.clear!
      expect(described_class.current).to be_nil
    end
  end

  describe '.clear!' do
    it 'removes the current event' do
      described_class.init!
      described_class.clear!
      expect(described_class.current).to be_nil
    end
  end

  describe 'thread isolation' do
    it 'isolates events between threads' do
      described_class.init!
      described_class.current.set(:thread, 'main')

      other_event = nil
      Thread.new do
        described_class.init!
        described_class.current.set(:thread, 'other')
        other_event = described_class.current.to_h
      end.join

      expect(described_class.current.to_h[:thread]).to eq('main')
      expect(other_event[:thread]).to eq('other')
    end
  end

  describe 'module-level convenience methods with active context' do
    before { described_class.init! }

    it 'delegates .add to current event' do
      CanonicalLog.add(foo: 'bar')
      expect(described_class.current.to_h[:foo]).to eq('bar')
    end

    it 'delegates .set to current event' do
      CanonicalLog.set(:key, 'value')
      expect(described_class.current.to_h[:key]).to eq('value')
    end

    it 'delegates .increment to current event' do
      CanonicalLog.increment(:counter, 5)
      expect(described_class.current.to_h[:counter]).to eq(5)
    end

    it 'delegates .append to current event' do
      CanonicalLog.append(:items, 'a')
      CanonicalLog.append(:items, 'b')
      expect(described_class.current.to_h[:items]).to eq(%w[a b])
    end

    it 'delegates .context to current event' do
      CanonicalLog.context(:user, id: 99)
      expect(described_class.current.to_h[:user]).to eq(id: 99)
    end

    it 'delegates .add_error to current event' do
      CanonicalLog.add_error(RuntimeError.new('oops'))
      expect(described_class.current.to_h[:error][:class]).to eq('RuntimeError')
    end
  end

  describe 'safe nil handling' do
    it 'does not raise when adding to nil context' do
      described_class.clear!
      expect { CanonicalLog.add(key: 'value') }.not_to raise_error
      expect { CanonicalLog.set(:key, 'value') }.not_to raise_error
      expect { CanonicalLog.increment(:key) }.not_to raise_error
      expect { CanonicalLog.append(:key, 'value') }.not_to raise_error
    end
  end
end
