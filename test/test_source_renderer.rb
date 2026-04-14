require_relative 'test_helper'

class SourceRendererTest < Minitest::Test
  SAMPLE_SECRETS    = [['h', 'a', 's', 'h'].map(&:ord), ['k', 'e', 'y'].map(&:ord), [1, 2, 3]]
  SAMPLE_FILE_NAMES = [['I', 'n', 'f', 'o'].map(&:ord)]

  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def output_path(name = 'secrets.swift')
    File.join(@tmpdir, name)
  end

  def render(algorithm: 'XOR', file_names: [], secrets: SAMPLE_SECRETS)
    renderer = MobileSecrets::SourceRenderer.new('swift')
    renderer.render_template(secrets, file_names, output_path, algorithm)
    File.read(output_path)
  end

  # ── XOR template ──────────────────────────────────────────────────────────

  def test_xor_template_writes_file
    renderer = MobileSecrets::SourceRenderer.new('swift')
    renderer.render_template(SAMPLE_SECRETS, [], output_path, 'XOR')
    assert File.exist?(output_path)
  end

  def test_xor_template_contains_xor_decrypt_function
    output = render(algorithm: 'XOR')
    assert_includes output, 'byte.element ^ password'
  end

  def test_xor_template_does_not_import_cryptokit
    output = render(algorithm: 'XOR')
    refute_includes output, 'import CryptoKit'
  end

  def test_xor_template_does_not_have_availability_annotation
    output = render(algorithm: 'XOR')
    refute_includes output, '@available'
  end

  def test_xor_template_contains_secrets_class
    output = render(algorithm: 'XOR')
    assert_includes output, 'class Secrets'
    assert_includes output, 'let standard = Secrets()'
  end

  def test_xor_template_embeds_byte_arrays
    output = render(algorithm: 'XOR')
    assert_includes output, 'private let bytes: [[UInt8]]'
  end

  def test_xor_template_contains_string_for_key_function
    output = render(algorithm: 'XOR')
    assert_includes output, 'func string(forKey key: String'
  end

  # ── AES-GCM template ──────────────────────────────────────────────────────

  def test_aes_gcm_template_writes_file
    renderer = MobileSecrets::SourceRenderer.new('swift')
    renderer.render_template(SAMPLE_SECRETS, [], output_path, 'AES-GCM')
    assert File.exist?(output_path)
  end

  def test_aes_gcm_template_imports_cryptokit
    output = render(algorithm: 'AES-GCM')
    assert_includes output, 'import CryptoKit'
  end

  def test_aes_gcm_template_has_availability_annotation
    output = render(algorithm: 'AES-GCM')
    assert_includes output, '@available(iOS 13.0'
  end

  def test_aes_gcm_template_uses_aes_gcm_nonce
    output = render(algorithm: 'AES-GCM')
    assert_includes output, 'AES.GCM.Nonce'
  end

  def test_aes_gcm_template_uses_sealed_box
    output = render(algorithm: 'AES-GCM')
    assert_includes output, 'AES.GCM.SealedBox'
  end

  def test_aes_gcm_template_does_not_contain_xor_logic
    output = render(algorithm: 'AES-GCM')
    refute_includes output, 'byte.element ^ password'
  end

  def test_aes_gcm_template_uses_symmetric_key
    output = render(algorithm: 'AES-GCM')
    assert_includes output, 'SymmetricKey'
  end

  # ── File decryption block (should_decrypt_files) ───────────────────────────

  def test_file_section_absent_when_no_files
    output = render(algorithm: 'XOR', file_names: [])
    refute_includes output, 'func decryptFiles'
    refute_includes output, 'AESFileCipher'
  end

  def test_file_section_present_when_files_configured
    output = render(algorithm: 'XOR', file_names: SAMPLE_FILE_NAMES)
    assert_includes output, 'func decryptFiles'
    assert_includes output, 'AESFileCipher'
  end

  def test_file_section_imports_common_crypto_when_files_configured
    output = render(algorithm: 'XOR', file_names: SAMPLE_FILE_NAMES)
    assert_includes output, 'import CommonCrypto'
  end

  def test_file_section_uses_pkcs7_padding
    output = render(algorithm: 'XOR', file_names: SAMPLE_FILE_NAMES)
    assert_includes output, 'kCCOptionPKCS7Padding'
  end

  def test_aes_gcm_with_files_imports_both_crypto_frameworks
    output = render(algorithm: 'AES-GCM', file_names: SAMPLE_FILE_NAMES)
    assert_includes output, 'import CryptoKit'
    assert_includes output, 'import CommonCrypto'
  end

  # ── Empty template ────────────────────────────────────────────────────────

  def test_empty_template_writes_file
    renderer = MobileSecrets::SourceRenderer.new('swift')
    renderer.render_empty_template(output_path)
    assert File.exist?(output_path)
  end

  def test_empty_template_contains_secrets_stub
    renderer = MobileSecrets::SourceRenderer.new('swift')
    renderer.render_empty_template(output_path)
    content = File.read(output_path)
    assert_includes content, 'class Secrets'
    assert_includes content, 'func string(forKey key: String'
  end

  def test_empty_template_has_placeholder_bytes
    renderer = MobileSecrets::SourceRenderer.new('swift')
    renderer.render_empty_template(output_path)
    content = File.read(output_path)
    assert_includes content, '[[0]]'
  end

  # ── algorithm default ──────────────────────────────────────────────────────

  def test_render_template_defaults_to_xor_when_algorithm_omitted
    renderer = MobileSecrets::SourceRenderer.new('swift')
    renderer.render_template(SAMPLE_SECRETS, [], output_path)
    content = File.read(output_path)
    assert_includes content, 'byte.element ^ password'
    refute_includes content, 'import CryptoKit'
  end
end
