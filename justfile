app := "macatat"
bundle_id := "com.mevanlc.macatat"
app_bundle := ".build/app/" + app + ".app"
install_path := "/Applications/" + app + ".app"
sign_identity := env("MACATAT_SIGN_IDENTITY", "macatat Local Code Signing")

# With only the Command Line Tools installed, SwiftPM can't find Swift Testing on its own.
clt_dev := "/Library/Developer/CommandLineTools/Library/Developer"
clt_test_flags := if `xcode-select -p` == "/Library/Developer/CommandLineTools" { "-Xswiftc -F -Xswiftc " + clt_dev / "Frameworks" + " -Xlinker -rpath -Xlinker " + clt_dev / "Frameworks" + " -Xlinker -rpath -Xlinker " + clt_dev / "usr/lib" } else { "" }

default: build

# Compile a release binary and assemble + sign .build/app/macatat.app.
build:
    #!/usr/bin/env bash
    set -euo pipefail
    swift build -c release --product {{app}}
    bin_dir="$(swift build -c release --show-bin-path)"
    rm -rf "{{app_bundle}}"
    mkdir -p "{{app_bundle}}/Contents/MacOS"
    cp "$bin_dir/{{app}}" "{{app_bundle}}/Contents/MacOS/"
    cp Support/Info.plist "{{app_bundle}}/Contents/"
    if security find-identity -v -p codesigning | grep -qF '"{{sign_identity}}"'; then
        codesign --force --sign "{{sign_identity}}" "{{app_bundle}}"
    else
        echo 'warning: no "{{sign_identity}}" signing identity; signing ad-hoc. Run `just cert` once so the Accessibility permission survives rebuilds.' >&2
        codesign --force --sign - "{{app_bundle}}"
    fi
    echo "Built {{app_bundle}}"

# Run the unit tests.
test:
    swift test {{clt_test_flags}}

# Build and launch the app from .build/app without installing it.
run: build
    open "{{app_bundle}}"

# Build, replace /Applications/macatat.app with the new bundle, and launch it.
install: build
    #!/usr/bin/env bash
    set -euo pipefail
    if pkill -x {{app}}; then
        for _ in {1..50}; do pgrep -x {{app}} >/dev/null || break; sleep 0.1; done
    fi
    rm -rf "{{install_path}}"
    ditto "{{app_bundle}}" "{{install_path}}"
    # An ad-hoc signature changes every build, which silently invalidates the
    # Accessibility grant; clear it so macOS asks again instead.
    if codesign -dvv "{{install_path}}" 2>&1 | grep -q '^Signature=adhoc'; then
        tccutil reset Accessibility {{bundle_id}} || true
    fi
    open "{{install_path}}"
    echo "Installed {{install_path}}"

# Builds signed with a self-signed identity keep their Accessibility permission across
# reinstalls; ad-hoc signatures change every build and lose it.

# One-time: create a self-signed code-signing identity in the login keychain.
cert:
    #!/usr/bin/env bash
    set -euo pipefail
    name="{{sign_identity}}"
    if security find-identity -v -p codesigning | grep -qF "\"$name\""; then
        echo "Signing identity \"$name\" already exists."
        exit 0
    fi
    keychain="$HOME/Library/Keychains/login.keychain-db"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=$name" \
        -addext "keyUsage=critical,digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" \
        -keyout "$tmp/key.pem" -out "$tmp/cert.pem" 2>/dev/null
    # OpenSSL 3 needs -legacy to write a PKCS#12 file that `security import` can read.
    openssl pkcs12 -export -legacy -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
        -out "$tmp/identity.p12" -passout pass:macatat 2>/dev/null \
        || openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
            -out "$tmp/identity.p12" -passout pass:macatat
    security import "$tmp/identity.p12" -k "$keychain" -P macatat -T /usr/bin/codesign
    echo "Trusting the certificate for code signing (macOS will ask for your password)..."
    security add-trusted-cert -r trustRoot -p codeSign -k "$keychain" "$tmp/cert.pem"
    echo "Created signing identity \"$name\"."

# Remove build products.
clean:
    rm -rf .build
