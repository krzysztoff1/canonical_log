# frozen_string_literal: true

RSpec.describe CanonicalLog::Formatters::Logfmt do
  describe '.format' do
    it 'formats flat key=value pairs' do
      result = described_class.format({ method: 'GET', status: 200 })
      expect(result).to eq('method=GET status=200')
    end

    it 'flattens nested hashes with dot notation' do
      result = described_class.format({ user: { id: 1, role: 'admin' } })
      expect(result).to include('user.id=1')
      expect(result).to include('user.role=admin')
    end

    it 'deeply nests with multiple levels' do
      result = described_class.format({ error: { context: { line: 42 } } })
      expect(result).to include('error.context.line=42')
    end

    it 'quotes strings containing spaces' do
      result = described_class.format({ message: 'GET /users 200' })
      expect(result).to eq('message="GET /users 200"')
    end

    it 'quotes strings containing equals signs' do
      result = described_class.format({ query: 'page=1' })
      expect(result).to eq('query="page=1"')
    end

    it 'escapes double quotes inside values' do
      result = described_class.format({ msg: 'said "hello"' })
      expect(result).to eq('msg="said \\"hello\\""')
    end

    it 'renders nil as empty value' do
      result = described_class.format({ field: nil })
      expect(result).to eq('field=')
    end

    it 'renders booleans unquoted' do
      result = described_class.format({ ok: true, fail: false })
      expect(result).to eq('ok=true fail=false')
    end

    it 'renders numeric values unquoted' do
      result = described_class.format({ count: 42, rate: 3.14 })
      expect(result).to eq('count=42 rate=3.14')
    end

    it 'joins arrays with commas' do
      result = described_class.format({ tags: ['a', 'b', 'c'] })
      expect(result).to eq('tags=a,b,c')
    end

    it 'quotes arrays containing spaces' do
      result = described_class.format({ tags: ['hello world', 'b'] })
      expect(result).to eq('tags="hello world,b"')
    end

    it 'includes all fields in a roundtrip' do
      input = {
        method: 'POST',
        path: '/api/orders',
        status: 201,
        duration_ms: 42.5,
        user: { id: 7 },
        tags: ['web', 'api'],
        error: nil,
        slow: true,
      }
      result = described_class.format(input)
      expect(result).to include('method=POST')
      expect(result).to include('path=/api/orders')
      expect(result).to include('status=201')
      expect(result).to include('duration_ms=42.5')
      expect(result).to include('user.id=7')
      expect(result).to include('tags=web,api')
      expect(result).to include('error=')
      expect(result).to include('slow=true')
    end
  end
end
