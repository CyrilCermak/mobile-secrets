require 'erb'

Book = Struct.new(:title, :author)
module MobileSecrets
  class SourceRenderer

    def initialize source_type
      @source_type = source_type.downcase
    end

    def render_template secrets_bytes, file_names_bytes, output_file_path
      template = ERB.new(File.read("#{__dir__}/../resources/SecretsSwift.erb"))

      case @source_type
      when "swift"
        File.open(output_file_path, "w") do |file|
           file.puts template.result_with_hash(secrets_array: secrets_bytes,
              file_names_array: file_names_bytes,
              should_decrypt_files: file_names_bytes.length > 0)
         end
      end
    end
    
    def render_empty_template output_file_path
      template = File.read("#{__dir__}/../resources/SecretsSwiftEmpty.erb")

      case @source_type
      when "swift"
        File.open(output_file_path, "w") do |file|
           file.puts template
         end
      end
    end

  end
end
