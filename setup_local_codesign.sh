#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build/codesign"
KEY_PEM="$BUILD_DIR/voiceinput_codesign_key.pem"
CERT_PEM="$BUILD_DIR/voiceinput_codesign_cert.pem"
P12_FILE="$BUILD_DIR/voiceinput_codesign.p12"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
IDENTITY_NAME="VoiceInput Local Code Signing"
OPENSSL_CONFIG="$BUILD_DIR/openssl_codesign.cnf"
P12_PASSWORD="voiceinput-local"

mkdir -p "$BUILD_DIR"

cat > "$OPENSSL_CONFIG" <<'EOF'
[req]
default_bits = 2048
distinguished_name = dn
x509_extensions = ext
prompt = no

[dn]
CN = VoiceInput Local Code Signing
O = Local Development
C = US

[ext]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "$IDENTITY_NAME"; then
  echo "Identity already exists: $IDENTITY_NAME"
  exit 0
fi

openssl req -x509 -newkey rsa:2048 -keyout "$KEY_PEM" -out "$CERT_PEM" -days 3650 -nodes -config "$OPENSSL_CONFIG"
openssl pkcs12 -export -legacy -out "$P12_FILE" -inkey "$KEY_PEM" -in "$CERT_PEM" -passout "pass:$P12_PASSWORD"

security import "$P12_FILE" -k "$KEYCHAIN" -P "$P12_PASSWORD" -f pkcs12 -T /usr/bin/codesign -T /usr/bin/security
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$CERT_PEM"

echo "Created local signing identity: $IDENTITY_NAME"
echo "You can now rebuild the app and macOS should treat it as the same signed app."
