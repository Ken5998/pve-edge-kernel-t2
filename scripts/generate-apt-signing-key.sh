#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 OUTPUT_DIRECTORY" >&2
  exit 2
fi

output_dir=$1
mkdir -p "${output_dir}"

if find "${output_dir}" -mindepth 1 -print -quit | grep -q .; then
  echo "Refusing to write into non-empty directory: ${output_dir}" >&2
  exit 1
fi

chmod 700 "${output_dir}"
gnupg_home=$(mktemp -d)
trap 'rm -rf "${gnupg_home}"' EXIT
chmod 700 "${gnupg_home}"

passphrase=$(gpg --homedir "${gnupg_home}" --gen-random 2 48 | base64 -w0)
printf '%s' "${passphrase}" > "${output_dir}/passphrase.txt"

cat > "${gnupg_home}/key-parameters" <<EOF
Key-Type: RSA
Key-Length: 4096
Key-Usage: sign
Name-Real: KSMVC PVE T2 Archive
Name-Email: apt@ksmvc.ch
Expire-Date: 5y
Passphrase: ${passphrase}
%commit
EOF

gpg --batch --homedir "${gnupg_home}" --generate-key "${gnupg_home}/key-parameters"
fingerprint=$(gpg --batch --homedir "${gnupg_home}" --with-colons --list-secret-keys |
  awk -F: '$1 == "fpr" { print $10; exit }')

gpg --batch \
  --homedir "${gnupg_home}" \
  --pinentry-mode loopback \
  --passphrase-file "${output_dir}/passphrase.txt" \
  --armor \
  --export-secret-keys "${fingerprint}" > "${output_dir}/private-key.asc"

gpg --batch \
  --homedir "${gnupg_home}" \
  --export-options export-minimal \
  --export "${fingerprint}" > "${output_dir}/public-key.gpg"

printf '%s\n' "${fingerprint}" > "${output_dir}/fingerprint.txt"
chmod 600 "${output_dir}"/*

echo "APT signing key generated in ${output_dir}"
echo "Fingerprint: ${fingerprint}"
