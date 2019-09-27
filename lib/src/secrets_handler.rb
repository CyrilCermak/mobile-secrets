require "dotgpg"

module MobileSecrets
  class SecretsHandler

    def initialize
      @secret_output_path = "./" #Path to your secret sturct in the project
    end

    def create path, configuration

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

    def inject_into_swift secrets_dict
      content = "struct AppSecrets {\n"
      secrets_dict.each { |key, value|  content << "\tstatic let #{key}: String? = #{value}\n" }
      content << "}"
      File.open("#{@secret_output_path}secrets.swift", "w") { |f| f.puts content }
    end
  end
end
