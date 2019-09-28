require "dotgpg"
require "yaml"
require_relative '../src/obfuscator'

module MobileSecrets
  class SecretsHandler

    def initialize
    end

    def export_secrets
      config = YAML.load(decrypt_secrets())["MobileSecrets"]
      hash_key = config["hashKey"]
      obfuscator = MobileSecrets::Obfuscator.new hash_key

      bytes = [hash_key.bytes]
      secrets_dict = config["secrets"]

      secrets_dict.each do |key, value|
        encrypted = obfuscator.obfuscate(value)
        bytes << key.bytes << encrypted.bytes
      end

      inject_secrets(bytes, "secrets.swift")
    end

    def inject_secrets(secret_bytes, file)
      template = IO.read "#{__dir__}/../resources/SecretsTemplate.swift"
      secret_bytes = "#{secret_bytes}".gsub "],", "],\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
      bytes_variable = "private let bytes: [[UInt8]] = #{secret_bytes}"
      swift_secrets = template.sub "/* SECRET BYTES */", bytes_variable

      File.open(file, "w") { |f| f.puts swift_secrets }
    end

    def decrypt
      decrypted_secrets = decrypt_secrets()
      secrets_dict = extract_secrets_from(decrypted_secrets)
      inject_into_swift(secrets_dict)
    end

    def dry_run *nil_secrets
      secrets_dict = {}
      nil_secrets.map { |s| secrets_dict[s] = "nil"  }
      inject_into_swift secrets_dict
    end

    private

    def decrypt_secrets
      gpg = Dotgpg::Dir.new "./"
      output = StringIO.new
      gpg.decrypt "secrets.gpg", output
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
