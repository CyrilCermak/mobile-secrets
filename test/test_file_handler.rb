require_relative 'test_helper'

class FileHandlerTest < Minitest::Test
  PASSWORD_32 = 'TestKey32CharLongForAES256Test!!'
  IV_SIZE     = 16 # AES-CBC block size used as IV

  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def write_tmp_file(name, content)
    path = File.join(@tmpdir, name)
    File.write(path, content)
    path
  end

  # ── Basic encryption ───────────────────────────────────────────────────────

  def test_encrypt_returns_binary_string
    path = write_tmp_file('secret.txt', 'hello world')
    handler = MobileSecrets::FileHandler.new(PASSWORD_32)
    result = handler.encrypt(path)
    assert_kind_of String, result
  end

  def test_encrypted_output_is_longer_than_input
    content = 'sensitive file content'
    path = write_tmp_file('data.txt', content)
    handler = MobileSecrets::FileHandler.new(PASSWORD_32)
    result = handler.encrypt(path)
    # Output must include IV (16 bytes) + at least one cipher block
    assert result.bytesize > content.bytesize
  end

  def test_encrypted_output_includes_iv_prefix
    path = write_tmp_file('data.txt', 'some content')
    handler = MobileSecrets::FileHandler.new(PASSWORD_32)
    result = handler.encrypt(path)
    assert result.bytesize >= IV_SIZE, 'Output must be at least IV_SIZE bytes'
  end

  def test_different_calls_produce_different_ciphertext
    path = write_tmp_file('data.txt', 'same content every time')
    handler = MobileSecrets::FileHandler.new(PASSWORD_32)
    first  = handler.encrypt(path)
    second = handler.encrypt(path)
    # Random IV means outputs must differ
    refute_equal first, second
  end

  def test_encrypt_round_trips_via_openssl
    content = 'my important plist content'
    path = write_tmp_file('info.txt', content)
    handler = MobileSecrets::FileHandler.new(PASSWORD_32)
    encrypted = handler.encrypt(path)

    # Manually decrypt to verify correctness
    iv         = encrypted[0, IV_SIZE]
    ciphertext = encrypted[IV_SIZE..]

    cipher = OpenSSL::Cipher::AES256.new(:CBC)
    cipher.decrypt
    cipher.iv  = iv
    cipher.key = PASSWORD_32
    decrypted = cipher.update(ciphertext) + cipher.final

    assert_equal content, decrypted
  end

  def test_empty_file_can_be_encrypted
    path = write_tmp_file('empty.txt', '')
    handler = MobileSecrets::FileHandler.new(PASSWORD_32)
    result = handler.encrypt(path)
    # Empty plaintext with PKCS7 padding produces one full AES block
    assert result.bytesize >= IV_SIZE
  end
end
