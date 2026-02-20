# frozen_string_literal: true

RSpec.describe CanonicalLog::Sinks::Stdout do
  subject(:sink) { described_class.new }

  describe '#write' do
    it 'writes to $stdout' do
      expect { sink.write('{"test":true}') }.to output("{\"test\":true}\n").to_stdout
    end
  end
end
