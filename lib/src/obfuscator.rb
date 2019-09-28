module MobileSecrets
  class Obfuscator

    def initialize obfuscation_keys
      @obfuscation_keys = obfuscation_keys
    end

    def deobfuscate(obfuscated_secret)
      xor_chiper(obfuscated_secret)
    end

    def obfuscate(secret)
      xor_chiper(secret)
    end

    def xor_chiper(secret)
      result = ""
      codepoints = secret.each_codepoint.to_a
      codepoints.each_index do |i|
          result += (codepoints[i] ^ @obfuscation_keys[i % @obfuscation_keys.size].ord).chr
      end
      result
    end
  end
end
