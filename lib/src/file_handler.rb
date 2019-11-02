require 'openssl'

module MobileSecrets
  class FileHandler

    def initialize password
      @password = password
    end

    def encrypt file
      file_content = File.read file
      cipher = OpenSSL::Cipher::AES256.new :CBC
      cipher.encrypt
      iv = cipher.random_iv
      cipher.key = @password
      cipher_text = iv + cipher.update(file_content) + cipher.final
      cipher_text
    end
  end
end
