# frozen_string_literal: true

RSpec.describe CanonicalLog::SqlSanitizer do
  describe '.sanitize' do
    it 'replaces single-quoted string literals' do
      sql = "SELECT * FROM users WHERE email = 'admin@example.com'"
      expect(described_class.sanitize(sql)).to eq("SELECT * FROM users WHERE email = '?'")
    end

    it 'replaces multiple string literals' do
      sql = "SELECT * FROM users WHERE email = 'a@b.com' AND name = 'John'"
      expect(described_class.sanitize(sql)).to eq("SELECT * FROM users WHERE email = '?' AND name = '?'")
    end

    it 'replaces numeric literals in value positions' do
      sql = 'SELECT * FROM users WHERE id = 42'
      expect(described_class.sanitize(sql)).to eq('SELECT * FROM users WHERE id = ?')
    end

    it 'replaces numeric literals after IN(' do
      sql = 'SELECT * FROM users WHERE id IN (1, 2, 3)'
      expect(described_class.sanitize(sql)).to eq('SELECT * FROM users WHERE id IN (?, ?, ?)')
    end

    it 'replaces decimal numeric literals' do
      sql = 'SELECT * FROM products WHERE price > 19.99'
      expect(described_class.sanitize(sql)).to eq('SELECT * FROM products WHERE price > ?')
    end

    it 'replaces negative numeric literals' do
      sql = 'SELECT * FROM accounts WHERE balance = -100'
      expect(described_class.sanitize(sql)).to eq('SELECT * FROM accounts WHERE balance = ?')
    end

    it 'does not mangle table names with numbers' do
      sql = "SELECT * FROM table2 WHERE col = 'val'"
      result = described_class.sanitize(sql)
      expect(result).to include('table2')
      expect(result).to include("'?'")
    end

    it 'does not mangle column names with numbers' do
      sql = "SELECT col1, col2 FROM users WHERE col1 = 'val'"
      result = described_class.sanitize(sql)
      expect(result).to include('col1')
      expect(result).to include('col2')
    end

    it 'handles strings with escaped quotes' do
      sql = "SELECT * FROM users WHERE name = 'O\\'Brien'"
      expect(described_class.sanitize(sql)).to eq("SELECT * FROM users WHERE name = '?'")
    end

    it 'returns nil-safe (passes through non-strings)' do
      expect(described_class.sanitize(nil)).to be_nil
    end

    it 'returns empty string as-is' do
      expect(described_class.sanitize('')).to eq('')
    end

    it 'handles INSERT with mixed literals' do
      sql = "INSERT INTO users (email, age) VALUES ('test@test.com', 25)"
      result = described_class.sanitize(sql)
      expect(result).to include("'?'")
      expect(result).not_to include('test@test.com')
    end
  end
end
