require 'minitest/autorun'
require 'minitest/reporters'
require 'tmpdir'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'mobile-secrets'
require 'src/obfuscator'
require 'src/secrets_handler'
require 'src/file_handler'
require 'src/source_renderer'

module TestFixtures
  HASH_KEY_32 = 'TestKey32CharLongForAES256Test!!'
  HASH_KEY_SHORT = 'ShortKey'

  XOR_YAML = <<~YAML
    MobileSecrets:
      hashKey: '#{HASH_KEY_32}'
      shouldIncludePassword: true
      language: Swift
      alg: XOR
      secrets:
        googleMaps: '123-maps-key'
        firebase: 'my-firebase-secret'
  YAML

  AES_GCM_YAML = <<~YAML
    MobileSecrets:
      hashKey: '#{HASH_KEY_32}'
      shouldIncludePassword: true
      language: Swift
      alg: AES-GCM
      secrets:
        googleMaps: '123-maps-key'
        firebase: 'my-firebase-secret'
  YAML

  NO_ALG_YAML = <<~YAML
    MobileSecrets:
      hashKey: '#{HASH_KEY_32}'
      shouldIncludePassword: true
      language: Swift
      secrets:
        apiKey: 'some-value'
  YAML

  NO_PASSWORD_YAML = <<~YAML
    MobileSecrets:
      hashKey: '#{HASH_KEY_32}'
      shouldIncludePassword: false
      language: Swift
      alg: XOR
      secrets:
        apiKey: 'some-value'
  YAML
end
