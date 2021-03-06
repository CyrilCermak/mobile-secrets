Gem::Specification.new do |s|
  s.name               = "mobile-secrets"
  s.version            = "0.0.9"

  s.authors = ["Cyril Cermak", "Joerg Nestele"]
  s.date = %q{2019-09-27}
  s.license = "MIT"
  s.description = %q{Handle mobile secrets the secure way with ease}
  s.email = %q{cyril.cermakk@gmail.com}
  s.files = ["Rakefile",
      "lib/mobile-secrets.rb",
      "lib/src/obfuscator.rb",
      "lib/src/secrets_handler.rb",
      "lib/src/source_renderer.rb",
      "lib/src/file_handler.rb",
      "lib/resources/example.yml",
      "lib/resources/SecretsSwift.erb",
      "lib/resources/SecretsSwiftEmpty.erb",
      "bin/mobile-secrets"]
  s.executables << 'mobile-secrets'
  # s.test_files = ["test/test_hola.rb"]
  s.add_dependency "dotgpg", "0.7.0"
  s.homepage = %q{https://github.com/CyrilCermak/mobile-secrets}
  s.require_paths = ["lib"]
  s.summary = %q{mobile-secrets tool for handling your mobile secrets}
end
