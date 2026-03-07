# frozen_string_literal: true

RSpec.describe CanonicalLog::Formatters::Pretty do
  describe '.format' do
    let(:hash) { { method: 'GET', path: '/orders', status: 200, cached: true, error: nil } }

    it 'returns indented JSON' do
      result = described_class.format(hash)
      stripped = result.gsub(/\e\[[0-9;]*m/, '')
      expect(stripped).to include("\n")
      expect(JSON.parse(stripped)).to eq(JSON.parse(hash.to_json))
    end

    it 'includes ANSI color codes' do
      result = described_class.format(hash)
      expect(result).to include("\e[")
    end

    it 'colorizes keys in cyan' do
      result = described_class.format(hash)
      expect(result).to include("\e[36m\"method\"\e[0m:")
    end

    it 'colorizes string values in green' do
      result = described_class.format(hash)
      expect(result).to include("\e[32m\"GET\"\e[0m")
    end

    it 'colorizes numbers in yellow' do
      result = described_class.format(hash)
      expect(result).to include("\e[33m200\e[0m")
    end

    it 'colorizes booleans in magenta' do
      result = described_class.format(hash)
      expect(result).to include("\e[35mtrue\e[0m")
    end

    it 'colorizes null in gray' do
      result = described_class.format(hash)
      expect(result).to include("\e[90mnull\e[0m")
    end

    it 'handles nested objects' do
      nested = { user: { id: 1, name: 'Alice' } }
      result = described_class.format(nested)
      stripped = result.gsub(/\e\[[0-9;]*m/, '')
      expect(JSON.parse(stripped)).to eq(JSON.parse(nested.to_json))
    end

    it 'handles arrays' do
      with_array = { tags: ['a', 'b'], counts: [1, 2] }
      result = described_class.format(with_array)
      stripped = result.gsub(/\e\[[0-9;]*m/, '')
      expect(JSON.parse(stripped)).to eq(JSON.parse(with_array.to_json))
    end

    it 'stripping ANSI yields valid JSON' do
      complex = { a: 'str', b: 42, c: true, d: false, e: nil, f: { g: [1, 'two'] } }
      result = described_class.format(complex)
      stripped = result.gsub(/\e\[[0-9;]*m/, '')
      expect { JSON.parse(stripped) }.not_to raise_error
    end
  end
end
