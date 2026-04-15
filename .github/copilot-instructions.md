# Mobile Secrets — Agent Instructions

## Project Overview

`mobile-secrets` is a Ruby CLI gem (v0.0.9) that helps mobile developers handle app secrets securely. It:

1. Reads a YAML config (`MobileSecrets.yml`) with key-value secrets and optional file paths.
2. Obfuscates secret values using an XOR cipher keyed on `hashKey`.
3. Stores the YAML config encrypted via GPG (`secrets.gpg`).
4. Exports a generated Swift source file (`secrets.swift`) containing obfuscated secrets as byte arrays.
5. Optionally encrypts arbitrary files (e.g. `Info.plist`) with AES-256-CBC for bundling in iOS projects.

**Authors:** Cyril Cermak, Joerg Nestele  
**License:** MIT  
**Homepage:** https://github.com/CyrilCermak/mobile-secrets

---

## Repository Structure

```
mobile-secrets/
├── bin/
│   └── mobile-secrets          # CLI entry point — parses ARGV and delegates to MobileSecrets::Cli
├── lib/
│   ├── mobile-secrets.rb       # Main module; defines MobileSecrets::Cli (perform_action, options, usage)
│   ├── src/
│   │   ├── obfuscator.rb       # MobileSecrets::Obfuscator — XOR cipher
│   │   ├── secrets_handler.rb  # MobileSecrets::SecretsHandler — GPG encrypt/decrypt, YAML processing
│   │   ├── source_renderer.rb  # MobileSecrets::SourceRenderer — ERB → Swift file generation
│   │   └── file_handler.rb     # MobileSecrets::FileHandler — AES-256-CBC file encryption (OpenSSL)
│   └── resources/
│       ├── example.yml         # Template YAML config (copied by --create-template)
│       ├── SecretsSwift.erb    # ERB template for full Swift Secrets class
│       └── SecretsSwiftEmpty.erb # ERB template for empty Swift Secrets class stub
├── Rakefile                    # rake / rake test — runs the test suite
├── mobile-secrets.gemspec      # Gem specification
└── .gitignore
```

---

## Module & Class Reference

### `MobileSecrets::Cli` (`lib/mobile-secrets.rb`)
The top-level CLI dispatcher.

| Method | Responsibility |
|--------|---------------|
| `perform_action(command, argv_1, argv_2)` | Big `case` on the CLI flag; calls the appropriate subsystem |
| `options` | Returns the help string listing all flags |
| `usage` | Returns the numbered step-by-step workflow string |
| `print_options` | Prints the ASCII banner + options |

### `MobileSecrets::SecretsHandler` (`lib/src/secrets_handler.rb`)
Orchestrates the full encrypt / decrypt pipeline.

| Method | Responsibility |
|--------|---------------|
| `export_secrets(path, from_encrypted_file_name)` | Decrypts GPG file → processes YAML → renders Swift file |
| `process_yaml_config(yaml_string)` | Parses YAML; builds `secrets_bytes` and `file_names_bytes` arrays |
| `encrypt(output_file_path, string, gpg_path)` | GPG-encrypts a string and writes to `output_file_path` |
| `encrypt_file(password, file, output_file_path)` | Delegates to `FileHandler` for AES encryption |
| `decrypt_secrets(encrypted_file_name)` *(private)* | Uses `Dotgpg::Dir` to decrypt `secrets.gpg` to a `StringIO` |

### `MobileSecrets::Obfuscator` (`lib/src/obfuscator.rb`)
Pure XOR cipher — obfuscation and deobfuscation are the same operation.

| Method | Responsibility |
|--------|---------------|
| `obfuscate(secret)` | XOR each codepoint of `secret` against cycling `@obfuscation_keys` |
| `deobfuscate(obfuscated_secret)` | Identical to `obfuscate` (XOR is its own inverse) |
| `xor_chiper(secret)` *(internal)* | Shared implementation for both directions |

### `MobileSecrets::SourceRenderer` (`lib/src/source_renderer.rb`)
Renders ERB templates to produce Swift source files.

| Method | Responsibility |
|--------|---------------|
| `render_template(secrets_bytes, file_names_bytes, output_file_path)` | Writes full `Secrets` Swift class using `SecretsSwift.erb` |
| `render_empty_template(output_file_path)` | Writes stub `Secrets` Swift class using `SecretsSwiftEmpty.erb` |

Template variables passed to `SecretsSwift.erb`:
- `secrets_array` — `[[Integer]]` (byte arrays of key names and XOR-obfuscated values)
- `file_names_array` — `[[Integer]]` (byte arrays of encrypted file names)
- `should_decrypt_files` — `Boolean` (controls whether AES / `CommonCrypto` blocks are emitted)

### `MobileSecrets::FileHandler` (`lib/src/file_handler.rb`)
AES-256-CBC encryption of arbitrary files via Ruby's `openssl` stdlib.

| Method | Responsibility |
|--------|---------------|
| `encrypt(file)` | Reads file, generates random IV, returns `iv + ciphertext` as binary |

---

## CLI Commands

| Flag | Arguments | Description |
|------|-----------|-------------|
| `--init-gpg` | `PATH` | Initialises a `dotgpg` GPG keyring in the given directory |
| `--create-template` | *(none)* | Copies `example.yml` to `./MobileSecrets.yml` |
| `--import` | `SECRETS_PATH [GPG_FILE]` | GPG-encrypts the YAML file; defaults to `secrets.gpg` |
| `--export` | `PATH [ENCRYPTED_FILE_PATH]` | Decrypts GPG file and writes `secrets.swift` to `PATH`; defaults to `secrets.gpg` |
| `--encrypt-file` | `FILE PASSWORD` | AES-256-CBC encrypts a single file; outputs `FILE.enc` |
| `--empty` | `PATH` | Writes an empty `Secrets` Swift stub to `PATH/secrets.swift` |
| `--edit` | `GPG_FILE` | Opens `dotgpg edit GPG_FILE` interactively |
| `--usage` | *(none)* | Prints numbered workflow instructions |

---

## Configuration File (`MobileSecrets.yml`)

```yaml
MobileSecrets:
  hashKey: "KokoBelloKokoKokoBelloKokoKokoBe"  # XOR key; must be 32 chars when encrypting files
  shouldIncludePassword: true                   # false = omit key bytes from generated Swift file
  language: "Swift"                             # Only "Swift" is currently supported
  secrets:
    googleMaps: "123123123"
    firebase: "asdasdasd"
  files:                                        # Optional; each file will be AES-encrypted to FILE.enc
    - tmp.txt
    - Info.plist
```

**Rules:**
- `hashKey` can be any length for XOR-only secrets, but **must be exactly 32 characters** when the `files` list is non-empty (AES-256 key size requirement).
- `shouldIncludePassword: false` omits the key from the Swift output; the caller must supply it at runtime (e.g. from Keychain or a remote API).
- The `language` field is parsed but currently only `"Swift"` triggers code generation. Kotlin support is planned.

---

## Security Model

1. **XOR obfuscation** — Each secret value is XOR'd byte-by-byte against the `hashKey`, cycling the key when shorter than the value. This is a compile-time obfuscation technique, not cryptographic encryption.
2. **AES-256-CBC file encryption** — Files are encrypted with OpenSSL AES-256-CBC; a random 16-byte IV is prepended to the ciphertext. The password must be exactly 32 bytes.
3. **GPG at-rest storage** — The plaintext YAML config is never stored on disk after import; it lives only inside `secrets.gpg`, which requires a GPG private key to decrypt.
4. **Swift runtime decryption** — The generated `Secrets` class uses `CommonCrypto` (`CCCrypt`) for AES-CBC decryption and a matching XOR loop to recover secret strings at runtime.

**Important:** The XOR cipher provides obfuscation (anti-casual-inspection), not cryptographic security. Secrets embedded in a binary can still be extracted by a determined attacker.

---

## Generated Swift File Structure

The exported `secrets.swift` contains a `Secrets` class with:

- `bytes: [[UInt8]]` — flat array where:
  - Index `0` = `hashKey` bytes (only if `shouldIncludePassword: true`)
  - Remaining pairs: `[key name bytes, XOR-obfuscated value bytes]`
- `fileNames: [[UInt8]]` — byte arrays of each encrypted file name (only if files are configured)
- `string(forKey:password:)` — looks up a key by name, then XOR-decrypts the adjacent value
- `decryptFiles(bundle:password:)` / `decryptFile(_:bundle:password:)` — AES-CBC decrypts `.enc` bundle resources
- Nested `AES` struct wrapping `CCCrypt`

Usage in iOS:
```swift
let apiKey = Secrets.standard.string(forKey: "googleMaps")
try? Secrets.standard.decryptFiles()  // Run once; decrypted file persists on disk
```

---

## Dependencies

| Gem | Version | Purpose |
|-----|---------|---------|
| `dotgpg` | `0.7.0` | GPG directory management — encrypt/decrypt `secrets.gpg` |
| `openssl` | stdlib | AES-256-CBC file encryption in `FileHandler` |
| `erb` | stdlib | Template rendering for Swift source generation |
| `yaml` | stdlib | Parsing `MobileSecrets.yml` |
| `rake` | stdlib | Task runner (`Rakefile`) |

---

## Build & Test

```sh
# Build the gem
gem build mobile-secrets.gemspec

# Install locally
gem install ./mobile-secrets-0.0.9.gem

# Run tests (test directory not yet populated)
rake test
# or simply:
rake
```

The `Rakefile` wires `Rake::TestTask` pointing at the `test/` directory. Tests do not exist yet — adding them is a known gap.

---

## Developer Workflow (End-to-End)

```sh
# 1. Initialise GPG keyring in current directory
mobile-secrets --init-gpg "."

# 2. Generate config template
mobile-secrets --create-template
# → creates ./MobileSecrets.yml

# 3. Edit MobileSecrets.yml — add your real hashKey and secrets

# 4. Encrypt the config into secrets.gpg
mobile-secrets --import ./MobileSecrets.yml

# 5. Generate secrets.swift for the iOS project
mobile-secrets --export ./MyApp/Sources/

# 6. Add secrets.swift to the Xcode project target

# 7. Delete MobileSecrets.yml — it is now safely stored in secrets.gpg
rm MobileSecrets.yml
```

To update secrets later:
```sh
mobile-secrets --edit secrets.gpg     # opens editor via dotgpg
mobile-secrets --export ./MyApp/Sources/
```

---

## Extending the Project

### Adding a New Target Language (e.g. Kotlin)
1. Create `lib/resources/SecretsKotlin.erb` mirroring the Swift template structure.
2. In `SourceRenderer#render_template`, add a `when "kotlin"` branch that renders the new template.
3. In `SourceRenderer#render_empty_template`, add the corresponding empty-stub branch.
4. The `language` field in the YAML config is already parsed in `SecretsHandler#process_yaml_config` — wire it through as a parameter to `SourceRenderer.new`.

### Adding a New CLI Command
1. Add a `when "--new-flag"` branch inside `MobileSecrets::Cli#perform_action`.
2. Append its description to the `options` string.
3. Implement the logic in the appropriate subsystem class or create a new one under `lib/src/`.

### Adding Tests
- Place test files under `test/` using Ruby's `minitest` (already wired in `Rakefile`).
- The key units to test are `Obfuscator` (XOR round-trip), `SecretsHandler#process_yaml_config`, and `SourceRenderer`.

---

## Known Limitations & Gotchas

- `language` config key is parsed but **not used** to select the template — `SourceRenderer` always defaults to Swift.
- `--export` silently falls back to `"secrets.gpg"` when no second argument is given (via `||=`), but the variable reassignment in `Cli#perform_action` is done on a local copy — the nil guard works correctly.
- File encryption requires the `hashKey` to be **exactly 32 characters**; the gem calls `abort` with a descriptive message if this is violated.
- The `Book = Struct.new(:title, :author)` line in `source_renderer.rb` is an unused leftover from scaffolding.
- No tests currently exist despite the `Rakefile` test task being defined.
- The `.gem` binary (`mobile-secrets-0.0.9.gem`) is committed to the repository — this is unconventional and should ideally be removed and distributed via RubyGems.org instead.