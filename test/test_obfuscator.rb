require_relative 'test_helper'

class ObfuscatorTest < Minitest::Test
  def setup
    @key = 'SecretKey'
    @obfuscator = MobileSecrets::Obfuscator.new(@key)
  end

  def test_obfuscate_returns_different_bytes_than_input
    result = @obfuscator.obfuscate('hello')
    refute_equal 'hello'.bytes, result.bytes
  end

  def test_xor_round_trip
    original = 'my-api-key-12345'
    obfuscated = @obfuscator.obfuscate(original)
    assert_equal original, @obfuscator.deobfuscate(obfuscated)
  end

  def test_obfuscate_and_deobfuscate_are_symmetric
    original = 'firebase-secret-abc'
    assert_equal original, @obfuscator.deobfuscate(@obfuscator.obfuscate(original))
    assert_equal original, @obfuscator.obfuscate(@obfuscator.deobfuscate(original))
  end

  def test_key_cycles_for_values_longer_than_key
    long_value = 'A' * 100
    obfuscated = @obfuscator.obfuscate(long_value)
    assert_equal long_value, @obfuscator.deobfuscate(obfuscated)
  end

  def test_output_length_equals_input_length
    value = 'exactly-twenty-chars'
    result = @obfuscator.obfuscate(value)
    assert_equal value.length, result.length
  end

  def test_different_keys_produce_different_output
    other = MobileSecrets::Obfuscator.new('OtherKey!')
    value = 'sensitive-data'
    refute_equal @obfuscator.obfuscate(value), other.obfuscate(value)
  end

  def test_empty_string_round_trips
    assert_equal '', @obfuscator.deobfuscate(@obfuscator.obfuscate(''))
  end

  def test_single_char_key_cycles
    obfuscator = MobileSecrets::Obfuscator.new('X')
    original = 'hello'
    assert_equal original, obfuscator.deobfuscate(obfuscator.obfuscate(original))
  end
end
