require_relative 'test_helper'

class SecretsHandlerTest < Minitest::Test
  include TestFixtures

  IV_SIZE  = 12
  TAG_SIZE = 16

  def setup
    @handler = MobileSecrets::SecretsHandler.new
  end

  # ── Algorithm selection ────────────────────────────────────────────────────

  def test_xor_algorithm_is_selected_when_specified
    _, _, alg = @handler.process_yaml_config(XOR_YAML)
    assert_equal 'XOR', alg
  end

  def test_aes_gcm_algorithm_is_selected_when_specified
    _, _, alg = @handler.process_yaml_config(AES_GCM_YAML)
    assert_equal 'AES-GCM', alg
  end

  def test_defaults_to_xor_when_alg_field_is_absent
    _, _, alg = @handler.process_yaml_config(NO_ALG_YAML)
    assert_equal 'XOR', alg
  end

  def test_alg_field_is_case_insensitive
    yaml = AES_GCM_YAML.sub("alg: AES-GCM", "alg: aes-gcm")
    _, _, alg = @handler.process_yaml_config(yaml)
    assert_equal 'AES-GCM', alg
  end

  def test_unsupported_algorithm_aborts
    yaml = XOR_YAML.sub("alg: XOR", "alg: RSA")
    assert_raises(SystemExit) { @handler.process_yaml_config(yaml) }
  end

  # ── shouldIncludePassword ──────────────────────────────────────────────────

  def test_hash_key_bytes_included_when_should_include_password_is_true
    _, secrets, _ = @handler.process_yaml_config(XOR_YAML)
    assert_equal HASH_KEY_32.bytes, secrets[0]
  end

  def test_hash_key_bytes_omitted_when_should_include_password_is_false
    _, secrets, _ = @handler.process_yaml_config(NO_PASSWORD_YAML)
    # First entry should be the key name bytes, not the hash key
    refute_equal HASH_KEY_32.bytes, secrets[0]
  end

  def test_secrets_bytes_count_with_password_included
    # hashKey + 2 secrets × (key bytes + value bytes) = 1 + 4 = 5 entries
    _, secrets, _ = @handler.process_yaml_config(XOR_YAML)
    assert_equal 5, secrets.length
  end

  def test_secrets_bytes_count_without_password
    # 1 secret × (key bytes + value bytes) = 2 entries
    _, secrets, _ = @handler.process_yaml_config(NO_PASSWORD_YAML)
    assert_equal 2, secrets.length
  end

  # ── XOR obfuscation ────────────────────────────────────────────────────────

  def test_xor_value_bytes_differ_from_plaintext
    _, secrets, _ = @handler.process_yaml_config(XOR_YAML)
    # secrets[1] is the key name 'googleMaps' bytes; secrets[2] is the XOR'd value
    plaintext_bytes = '123-maps-key'.bytes
    refute_equal plaintext_bytes, secrets[2]
  end

  def test_xor_value_can_be_deobfuscated_back_to_original
    _, secrets, _ = @handler.process_yaml_config(XOR_YAML)
    obfuscator = MobileSecrets::Obfuscator.new(HASH_KEY_32)
    value_bytes = secrets[2]
    recovered = obfuscator.deobfuscate(value_bytes.pack('C*'))
    assert_equal '123-maps-key', recovered
  end

  def test_xor_key_name_bytes_are_unobfuscated
    _, secrets, _ = @handler.process_yaml_config(XOR_YAML)
    # secrets[1] = 'googleMaps' key name bytes
    assert_equal 'googleMaps'.bytes, secrets[1]
  end

  # ── AES-GCM obfuscation ────────────────────────────────────────────────────

  def test_aes_gcm_value_bytes_meet_minimum_length
    _, secrets, _ = @handler.process_yaml_config(AES_GCM_YAML)
    # secrets[2] = encrypted '123-maps-key' (12 chars)
    # Minimum: IV(12) + Tag(16) + Ciphertext(1+) = 29+ bytes
    value_bytes = secrets[2]
    assert value_bytes.length >= IV_SIZE + TAG_SIZE + 1,
      "AES-GCM output too short: #{value_bytes.length} bytes"
  end

  def test_aes_gcm_value_bytes_exact_length
    _, secrets, _ = @handler.process_yaml_config(AES_GCM_YAML)
    plaintext_len = '123-maps-key'.length  # 12
    expected_len  = IV_SIZE + TAG_SIZE + plaintext_len
    assert_equal expected_len, secrets[2].length
  end

  def test_aes_gcm_produces_same_ciphertext_on_repeated_calls
    _, secrets1, _ = @handler.process_yaml_config(AES_GCM_YAML)
    _, secrets2, _ = @handler.process_yaml_config(AES_GCM_YAML)
    # Deterministic IV means the same input always produces the same encrypted bytes
    assert_equal secrets1[2], secrets2[2]
  end

  def test_aes_gcm_produces_different_ciphertext_for_different_secret_names
    yaml_a = AES_GCM_YAML.sub('googleMaps', 'nameA')
    yaml_b = AES_GCM_YAML.sub('googleMaps', 'nameB')
    _, secrets_a, _ = @handler.process_yaml_config(yaml_a)
    _, secrets_b, _ = @handler.process_yaml_config(yaml_b)
    # Different secret names derive different IVs — no nonce reuse
    refute_equal secrets_a[1], secrets_b[1]  # different key name bytes
    refute_equal secrets_a[2], secrets_b[2]  # different ciphertext
  end

  def test_aes_gcm_produces_different_ciphertext_for_different_values
    yaml_v1 = AES_GCM_YAML.sub('123-maps-key', 'value-v1')
    yaml_v2 = AES_GCM_YAML.sub('123-maps-key', 'value-v2')
    _, secrets1, _ = @handler.process_yaml_config(yaml_v1)
    _, secrets2, _ = @handler.process_yaml_config(yaml_v2)
    # Different values derive different IVs — no nonce reuse on secret rotation
    refute_equal secrets1[2], secrets2[2]
  end

  def test_aes_gcm_value_decrypts_to_original
    _, secrets, _ = @handler.process_yaml_config(AES_GCM_YAML)
    raw    = secrets[2].pack('C*')
    iv     = raw[0, IV_SIZE]
    tag    = raw[IV_SIZE, TAG_SIZE]
    cipher_text = raw[(IV_SIZE + TAG_SIZE)..]

    cipher = OpenSSL::Cipher::AES256.new(:GCM)
    cipher.decrypt
    cipher.iv       = iv
    cipher.key      = HASH_KEY_32
    cipher.auth_tag = tag
    cipher.auth_data = ''
    decrypted = cipher.update(cipher_text) + cipher.final

    assert_equal '123-maps-key', decrypted
  end

  def test_aes_gcm_key_name_bytes_are_unobfuscated
    _, secrets, _ = @handler.process_yaml_config(AES_GCM_YAML)
    assert_equal 'googleMaps'.bytes, secrets[1]
  end

  def test_aes_gcm_requires_32_char_hash_key
    yaml = AES_GCM_YAML.sub(HASH_KEY_32, 'ShortKey')
    assert_raises(SystemExit) { @handler.process_yaml_config(yaml) }
  end

  # ── File names ─────────────────────────────────────────────────────────────

  def test_file_names_bytes_empty_when_no_files_configured
    file_names, _, _ = @handler.process_yaml_config(XOR_YAML)
    assert_empty file_names
  end
end
