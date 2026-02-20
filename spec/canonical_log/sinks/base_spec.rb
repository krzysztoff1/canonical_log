# frozen_string_literal: true

RSpec.describe CanonicalLog::Sinks::Base do
  describe '#write' do
    it 'raises NotImplementedError' do
      expect { described_class.new.write('{}') }.to raise_error(NotImplementedError)
    end
  end
end
