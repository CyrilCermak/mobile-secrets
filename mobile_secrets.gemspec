Gem::Specification.new do |s|
  s.name               = "mobile_secrets"
  s.version            = "0.0.1"
  s.default_executable = "mobile_secrets"

  s.authors = ["Cyril Cermak", "Joerg Nestele"]
  s.date = %q{2019-09-27}
  s.description = %q{Handle mobile secrets the secure way with ease}
  s.email = %q{cyril.cermakk@gmail.com}
  s.files = ["Rakefile", "lib/src/bfuscator.rb", "lib/src/secrets_handler.rb", "bin/secrets_handler"]
  s.test_files = ["test/test_hola.rb"]
  s.homepage = %q{http://rubygems.org/gems/hola}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.6.2}
  s.summary = %q{Hola!}
end
