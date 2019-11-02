require "dotgpg"
require "yaml"

require_relative '../src/obfuscator'
require_relative '../src/file_handler'
require_relative '../src/source_renderer'

module MobileSecrets
  class SecretsHandler

    def export_secrets path
      decrypted_config = decrypt_secrets()
      bytes, include_files = process_yaml_config decrypted_config

      renderer = MobileSecrets::SourceRenderer.new "swift"
      renderer.render_template bytes, include_files, "#{path}/secrets.swift"
    end

    def process_yaml_config yaml_string
      config = YAML.load(yaml_string)["MobileSecrets"]
      hash_key = config["hashKey"]
      obfuscator = MobileSecrets::Obfuscator.new hash_key

      bytes = [hash_key.bytes]
      secrets_dict = config["secrets"]

      secrets_dict.each do |key, value|
        encrypted = obfuscator.obfuscate(value)
        bytes << key.bytes << encrypted.bytes
      end

      contain_files = false
      files = config["files"]
      if files
        abort("Password must be 13 characters long for files encryption.") if hash_key.length != 32
        files.each { |f| encrypt_file hash_key, f, "#{f}.enc" }
        contain_files = true
      end

      return bytes, contain_files
    end

    # Deprecated: use renderer
    def inject_secrets secret_bytes, file
      template = IO.read "#{__dir__}/../resources/SecretsTemplate.swift"
      secret_bytes = "#{secret_bytes}".gsub "],", "],\n                                   " #Formating the array
      bytes_variable = "private let bytes: [[UInt8]] = #{secret_bytes}"
      swift_secrets = template.sub "/* SECRET BYTES */", bytes_variable

      File.open(file, "w") { |f| f.puts swift_secrets }
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
