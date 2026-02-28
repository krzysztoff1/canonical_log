# frozen_string_literal: true

RSpec.describe CanonicalLog::Sinks::Null do
  subject(:sink) { described_class.new }

  describe '#write' do
    it 'does not write to stdout' do
      expect { sink.write('{"test":true}') }.not_to output.to_stdout
    end
  end
end
