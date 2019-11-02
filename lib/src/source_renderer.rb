require 'erb'

Book = Struct.new(:title, :author)
module MobileSecrets
  class SourceRenderer

    def initialize source_type
      @source_type = source_type.downcase
    end

    def render_template secrets_array, should_decrypt_files, output_file_path
      template = ERB.new(File.read("#{__dir__}/../resources/SecretsSwift.erb"))

      case @source_type
      when "swift"
        File.open(output_file_path, "w") do |file|
           file.puts template.result_with_hash(secrets_array: secrets_array, should_decrypt_files: should_decrypt_files)
         end
      end
    end

  end
end
