require "dotgpg"
require "yaml"
require "openssl"
require "stringio"

require_relative '../src/obfuscator'
require_relative '../src/file_handler'
require_relative '../src/source_renderer'

module MobileSecrets
  class SecretsHandler

    SUPPORTED_ALGORITHMS = %w[XOR AES-GCM].freeze

    def export_secrets path, from_encrypted_file_name
      decrypted_config = decrypt_secrets(from_encrypted_file_name)
      file_names_bytes, secrets_bytes, algorithm = process_yaml_config decrypted_config

      renderer = MobileSecrets::SourceRenderer.new "swift"
      renderer.render_template secrets_bytes, file_names_bytes, "#{path}/secrets.swift", algorithm
      decrypted_config
    end

    def process_yaml_config yaml_string
      config = YAML.safe_load(yaml_string)["MobileSecrets"]
      hash_key = config["hashKey"]
      secrets_dict = config["secrets"]
      files = config["files"]
      should_include_password = config["shouldIncludePassword"]
      algorithm = (config["alg"] || "XOR").upcase

      abort("Unsupported algorithm '#{algorithm}'. Valid options: #{SUPPORTED_ALGORITHMS.join(', ')}.") \
        unless SUPPORTED_ALGORITHMS.include?(algorithm)
      abort("hashKey must be exactly 32 characters for AES-GCM encryption.") \
        if algorithm == "AES-GCM" && hash_key.length != 32

      secrets_bytes = should_include_password ? [hash_key.bytes] : []
      file_names_bytes = []
      obfuscator = MobileSecrets::Obfuscator.new hash_key

      secrets_dict.each do |key, value|
        if algorithm == "AES-GCM"
          secrets_bytes << key.bytes << encrypt_aes_gcm(value.to_s, hash_key, key)
        else
          encrypted = obfuscator.obfuscate(value.to_s)
          secrets_bytes << key.bytes << encrypted.bytes
        end
      end

      if files
        abort("hashKey must be 32 characters long for files encryption.") if hash_key.length != 32
        files.each do |f|
          encrypt_file hash_key, f, "#{f}.enc"
          file_names_bytes << f.bytes
        end
      end

      return file_names_bytes, secrets_bytes, algorithm
    end

    def encrypt output_file_path, string, gpg_path
      gpg_path = "." unless gpg_path
      gpg_path =  "#{Dir.pwd}/#{gpg_path}"
      dotgpg = Dotgpg::Dir.new(gpg_path)
      dotgpg.encrypt output_file_path, string
    end

    def encrypt_file password, file, output_file_path
      encryptor = FileHandler.new password
      abort("Configuration contains file #{file} that cannot be found! Please check your mobile-secrets configuration or add the file into directory.") unless File.exist? file
      encrypted_content = encryptor.encrypt file

      File.open(output_file_path, "wb") { |f| f.write encrypted_content }
    end

    private

    # Encrypts a secret value with AES-256-GCM using a deterministic IV.
    # The IV is derived via HMAC-SHA256(key, "secret_name:value") truncated to 12 bytes,
    # so identical inputs always produce identical ciphertext while ensuring that
    # changing either the value or the secret name produces a different IV — preventing
    # nonce reuse, which would be catastrophic for GCM authentication.
    # Returns bytes laid out as: IV(12) + AuthTag(16) + Ciphertext(N)
    def encrypt_aes_gcm(value, key_string, secret_name)
      iv = OpenSSL::HMAC.digest('SHA256', key_string, "#{secret_name}:#{value}")[0, 12]
      cipher = OpenSSL::Cipher::AES256.new(:GCM)
      cipher.encrypt
      cipher.iv = iv
      cipher.key = key_string
      cipher.auth_data = ""
      ciphertext = cipher.update(value) + cipher.final
      tag = cipher.auth_tag(16)
      (iv + tag + ciphertext).bytes
    end

    def decrypt_secrets encrypted_file_name
      gpg = Dotgpg::Dir.closest encrypted_file_name
      output = StringIO.new
      gpg.decrypt "#{Dir.pwd}/#{encrypted_file_name}", output
      output.string
    end

    def extract_secrets_from secrets_payload
      secrets = {}
      secrets_payload.split("\n").each do |l|
        keysWithsecret = l.split("=")
        secrets[keysWithsecret[0].strip] = keysWithsecret[1].strip
      end
      secrets
    end
  end
end
