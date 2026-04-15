require_relative 'test_helper'
require 'open3'
require 'tmpdir'

# End-to-end tests that:
#   1. Seed a YAML config with known secrets
#   2. Run the full Ruby encryption pipeline (process_yaml_config + render_template)
#   3. Compile the generated secrets.swift + a Swift harness with swiftc
#   4. Execute the binary and assert the decrypted output matches the original secrets
#
# These tests exercise the complete data path from YAML → obfuscated bytes → Swift source →
# compiled binary → decrypted string, covering both XOR and AES-GCM algorithms.
class E2eTest < Minitest::Test
  include TestFixtures

  KNOWN_SECRETS = {
    'googleMaps' => '123-maps-key',
    'firebase'   => 'my-firebase-secret'
  }.freeze

  SDK_PATH = `xcrun --show-sdk-path`.strip.freeze

  def setup
    skip 'swiftc not found — skipping E2E tests' unless system('which swiftc > /dev/null 2>&1')
    @tmpdir  = Dir.mktmpdir('mobile-secrets-e2e')
    @handler = MobileSecrets::SecretsHandler.new
    @renderer = MobileSecrets::SourceRenderer.new('swift')
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
  end

  # ── XOR + password embedded in binary ─────────────────────────────────────

  def test_xor_with_embedded_password_round_trips_all_secrets
    output = run_pipeline(yaml: XOR_YAML, algorithm: 'XOR', keys: KNOWN_SECRETS.keys)

    KNOWN_SECRETS.each do |key, expected|
      assert_includes output, "#{key}=#{expected}",
        "Expected '#{key}=#{expected}' in output:\n#{output}"
    end
  end

  # ── AES-GCM + password embedded in binary ─────────────────────────────────

  def test_aes_gcm_with_embedded_password_round_trips_all_secrets
    output = run_pipeline(yaml: AES_GCM_YAML, algorithm: 'AES-GCM', keys: KNOWN_SECRETS.keys)

    KNOWN_SECRETS.each do |key, expected|
      assert_includes output, "#{key}=#{expected}",
        "Expected '#{key}=#{expected}' in output:\n#{output}"
    end
  end

  # ── AES-GCM: each export produces different ciphertext (random IV) but same decrypted output

  def test_aes_gcm_produces_identical_swift_source_on_repeated_exports
    output1 = run_pipeline(yaml: AES_GCM_YAML, algorithm: 'AES-GCM', keys: KNOWN_SECRETS.keys,
                           swift_name: 'secrets1.swift', binary_name: 'bin1')
    output2 = run_pipeline(yaml: AES_GCM_YAML, algorithm: 'AES-GCM', keys: KNOWN_SECRETS.keys,
                           swift_name: 'secrets2.swift', binary_name: 'bin2')

    # Both runs decrypt to the same values
    KNOWN_SECRETS.each do |key, expected|
      assert_includes output1, "#{key}=#{expected}"
      assert_includes output2, "#{key}=#{expected}"
    end

    # Sources are identical — deterministic IV means reproducible builds
    src1 = File.read(File.join(@tmpdir, 'secrets1.swift'))
    src2 = File.read(File.join(@tmpdir, 'secrets2.swift'))
    assert_equal src1, src2, 'AES-GCM sources should be identical across exports (deterministic IV)'
  end

  # ── XOR + password supplied at runtime (shouldIncludePassword: false) ─────

  def test_xor_with_runtime_password_round_trips_all_secrets
    yaml = XOR_YAML.sub('shouldIncludePassword: true', 'shouldIncludePassword: false')
    output = run_pipeline(yaml: yaml, algorithm: 'XOR', keys: KNOWN_SECRETS.keys,
                          runtime_password: HASH_KEY_32)

    KNOWN_SECRETS.each do |key, expected|
      assert_includes output, "#{key}=#{expected}",
        "Expected '#{key}=#{expected}' in output:\n#{output}"
    end
  end

  # ── AES-GCM + password supplied at runtime (shouldIncludePassword: false) ─

  def test_aes_gcm_with_runtime_password_round_trips_all_secrets
    yaml = AES_GCM_YAML.sub('shouldIncludePassword: true', 'shouldIncludePassword: false')
    output = run_pipeline(yaml: yaml, algorithm: 'AES-GCM', keys: KNOWN_SECRETS.keys,
                          runtime_password: HASH_KEY_32)

    KNOWN_SECRETS.each do |key, expected|
      assert_includes output, "#{key}=#{expected}",
        "Expected '#{key}=#{expected}' in output:\n#{output}"
    end
  end

  # ── Wrong password yields no output ───────────────────────────────────────

  def test_xor_with_wrong_runtime_password_returns_no_secrets
    yaml = XOR_YAML.sub('shouldIncludePassword: true', 'shouldIncludePassword: false')
    output = run_pipeline(yaml: yaml, algorithm: 'XOR', keys: KNOWN_SECRETS.keys,
                          runtime_password: 'WrongKey32CharLongForAES256!!!!!',
                          swift_name: 'secrets_wp.swift', binary_name: 'bin_wp')

    KNOWN_SECRETS.each do |_, expected|
      refute_includes output, expected,
        "Expected wrong password to prevent decryption but got: #{output}"
    end
  end

  private

  # Runs the full Ruby → Swift → compile → execute pipeline.
  # Returns the stdout of the executed binary.
  def run_pipeline(yaml:, algorithm:, keys:, runtime_password: nil,
                   swift_name: 'secrets.swift', binary_name: 'test_secrets')
    swift_path  = File.join(@tmpdir, swift_name)
    harness_path = File.join(@tmpdir, "harness_#{binary_name}.swift")
    binary_path  = File.join(@tmpdir, binary_name)

    # Step 1: encrypt secrets and render Swift source
    file_names, secrets, alg = @handler.process_yaml_config(yaml)
    @renderer.render_template(secrets, file_names, swift_path, alg)

    # Step 2: write Swift harness that calls string(forKey:) for each key
    write_harness(harness_path, keys, algorithm, runtime_password)

    # Step 3: compile
    compile!(swift_path, harness_path, binary_path)

    # Step 4: execute and return output
    stdout, stderr, status = Open3.capture3(binary_path)
    assert status.success?, "Binary exited with #{status.exitstatus}. stderr: #{stderr}"
    stdout.strip
  end

  # Writes a @main Swift harness that looks up each key and prints "key=value" lines.
  def write_harness(path, keys, algorithm, password)
    pw_arg    = password ? ", password: \"#{password}\"" : ''
    lookups   = keys.map { |k|
      "        if let v = Secrets.standard.string(forKey: \"#{k}\"#{pw_arg}) { print(\"#{k}=\\(v)\") }"
    }.join("\n")

    body = if algorithm == 'AES-GCM'
      <<~SWIFT
        @main struct Harness {
            static func main() {
                if #available(macOS 10.15, *) {
        #{lookups}
                }
            }
        }
      SWIFT
    else
      <<~SWIFT
        @main struct Harness {
            static func main() {
        #{lookups}
            }
        }
      SWIFT
    end

    File.write(path, body)
  end

  # Compiles secrets.swift + harness.swift into a binary.
  # Asserts success and surfaces any compiler errors.
  def compile!(swift_path, harness_path, binary_path)
    cmd = "swiftc -sdk #{SDK_PATH} #{swift_path} #{harness_path} -o #{binary_path}"
    stdout, stderr, status = Open3.capture3(cmd)
    assert status.success?,
      "swiftc compilation failed:\n#{stderr}\n#{stdout}\n\n" \
      "Generated Swift source:\n#{File.read(swift_path)}"
  end
end
