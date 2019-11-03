require "dotgpg"
require "yaml"

require_relative '../src/obfuscator'
require_relative '../src/file_handler'
require_relative '../src/source_renderer'

module MobileSecrets
  class SecretsHandler

    def export_secrets path
      decrypted_config = decrypt_secrets()
      file_names_bytes, secrets_bytes = process_yaml_config decrypted_config

      renderer = MobileSecrets::SourceRenderer.new "swift"
      renderer.render_template secrets_bytes, file_names_bytes, "#{path}/secrets.swift"
    end

    def process_yaml_config yaml_string
      config = YAML.load(yaml_string)["MobileSecrets"]
      hash_key = config["hashKey"]
      secrets_dict = config["secrets"]
      files = config["files"]
      should_include_password = config["shouldIncludePassword"]
      secrets_bytes = should_include_password ? [hash_key.bytes] : []
      file_names_bytes = []
      obfuscator = MobileSecrets::Obfuscator.new hash_key

      secrets_dict.each do |key, value|
        encrypted = obfuscator.obfuscate(value)
        secrets_bytes << key.bytes << encrypted.bytes
      end

      if files
        abort("Password must be 32 characters long for files encryption.") if hash_key.length != 32
        files.each do |f|
          encrypt_file hash_key, f, "#{f}.enc"
          file_names_bytes << f.bytes
        end
      end

      return file_names_bytes, secrets_bytes
    end

    def encrypt output_file_path, string, gpg_path
      gpg_path = "." unless gpg_path
      gpg_path =  "#{Dir.pwd}/#{gpg_path}"
      dotgpg = Dotgpg::Dir.new(gpg_path)
      dotgpg.encrypt output_file_path, string
    end

    def encrypt_file password, file, output_file_path
      encryptor = FileHandler.new password
      encrypted_content = encryptor.encrypt file

      File.open(output_file_path, "wb") { |f| f.write encrypted_content }
    end

    private

    def decrypt_secrets
      gpg = Dotgpg::Dir.new "#{Dir.pwd}/"
      output = StringIO.new
      gpg.decrypt "#{Dir.pwd}/secrets.gpg", output
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
