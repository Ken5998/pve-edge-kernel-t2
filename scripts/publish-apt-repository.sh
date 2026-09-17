#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 DEB_DIRECTORY" >&2
  exit 2
fi

for required_variable in \
  R2_ACCOUNT_ID \
  R2_ACCESS_KEY_ID \
  R2_SECRET_ACCESS_KEY \
  APT_GPG_PRIVATE_KEY \
  APT_GPG_PASSPHRASE; do
  if [[ -z "${!required_variable:-}" ]]; then
    echo "Missing required environment variable: ${required_variable}" >&2
    exit 1
  fi
done

deb_directory=$1
bucket_name=${R2_BUCKET_NAME:-pve-t2-apt}
repository_dir=$(mktemp -d)
gnupg_home=$(mktemp -d)
trap 'rm -rf "${repository_dir}" "${gnupg_home}"' EXIT
chmod 700 "${gnupg_home}"

export AWS_ACCESS_KEY_ID=${R2_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${R2_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=auto
export GNUPGHOME=${gnupg_home}
r2_endpoint="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

mkdir -p "${repository_dir}/pool/main/p/proxmox-kernel-t2"
aws s3 sync \
  "s3://${bucket_name}/pool" \
  "${repository_dir}/pool" \
  --endpoint-url "${r2_endpoint}" \
  --only-show-errors

mapfile -t kernel_debs < <(
  find "${deb_directory}" -maxdepth 1 -type f \
    -name 'proxmox-kernel-*-pve-t2_*_amd64.deb' -print
)
mapfile -t header_debs < <(
  find "${deb_directory}" -maxdepth 1 -type f \
    -name 'proxmox-headers-*-pve-t2_*_amd64.deb' -print
)

if [[ ${#kernel_debs[@]} -ne 1 || ${#header_debs[@]} -ne 1 ]]; then
  echo "Expected exactly one T2 kernel and one T2 header package." >&2
  printf 'Kernel packages: %s\n' "${kernel_debs[*]:-none}" >&2
  printf 'Header packages: %s\n' "${header_debs[*]:-none}" >&2
  exit 1
fi

pool_directory="${repository_dir}/pool/main/p/proxmox-kernel-t2"
cp "${kernel_debs[0]}" "${header_debs[0]}" "${pool_directory}/"

kernel_package=$(dpkg-deb --field "${kernel_debs[0]}" Package)
kernel_version=$(dpkg-deb --field "${kernel_debs[0]}" Version)
header_package=$(dpkg-deb --field "${header_debs[0]}" Package)
header_version=$(dpkg-deb --field "${header_debs[0]}" Version)

meta_root=$(mktemp -d)
mkdir -p "${meta_root}/DEBIAN"
cat > "${meta_root}/DEBIAN/control" <<EOF
Package: proxmox-kernel-t2
Version: ${kernel_version}
Section: kernel
Priority: optional
Architecture: amd64
Depends: ${kernel_package} (= ${kernel_version}), ${header_package} (= ${header_version})
Maintainer: KSMVC <apt@ksmvc.ch>
Description: Latest Proxmox VE kernel and headers for T2 Macs
 This metapackage installs the latest KSMVC Proxmox kernel and headers
 carrying the T2 Linux patches.
EOF

dpkg-deb --build --root-owner-group \
  "${meta_root}" \
  "${pool_directory}/proxmox-kernel-t2_${kernel_version}_amd64.deb"
rm -rf "${meta_root}"

packages_directory="${repository_dir}/dists/trixie/main/binary-amd64"
mkdir -p "${packages_directory}"
(
  cd "${repository_dir}"
  apt-ftparchive packages pool > "dists/trixie/main/binary-amd64/Packages"
)
gzip -9nk "${packages_directory}/Packages"

(
  cd "${repository_dir}"
  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin='KSMVC' \
    -o APT::FTPArchive::Release::Label='KSMVC PVE T2' \
    -o APT::FTPArchive::Release::Suite='trixie' \
    -o APT::FTPArchive::Release::Codename='trixie' \
    -o APT::FTPArchive::Release::Architectures='amd64' \
    -o APT::FTPArchive::Release::Components='main' \
    -o APT::FTPArchive::Release::Description='Proxmox VE kernels for T2 Macs' \
    release dists/trixie > dists/trixie/Release
)

printf '%s\n' "${APT_GPG_PRIVATE_KEY}" | gpg --batch --import
fingerprint=$(gpg --batch --with-colons --list-secret-keys |
  awk -F: '$1 == "fpr" { print $10; exit }')

printf '%s' "${APT_GPG_PASSPHRASE}" | gpg \
  --batch \
  --yes \
  --pinentry-mode loopback \
  --passphrase-fd 0 \
  --local-user "${fingerprint}" \
  --clearsign \
  --output "${repository_dir}/dists/trixie/InRelease" \
  "${repository_dir}/dists/trixie/Release"

printf '%s' "${APT_GPG_PASSPHRASE}" | gpg \
  --batch \
  --yes \
  --pinentry-mode loopback \
  --passphrase-fd 0 \
  --local-user "${fingerprint}" \
  --armor \
  --detach-sign \
  --output "${repository_dir}/dists/trixie/Release.gpg" \
  "${repository_dir}/dists/trixie/Release"

gpg --batch --export-options export-minimal --export "${fingerprint}" > \
  "${repository_dir}/ksmvc-archive-keyring.gpg"

cat > "${repository_dir}/ksmvc-t2.sources" <<'EOF'
Types: deb
URIs: https://apt.ksmvc.ch
Suites: trixie
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/ksmvc-archive-keyring.gpg
EOF

cat > "${repository_dir}/index.html" <<EOF
<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><title>KSMVC PVE T2 APT repository</title></head>
  <body>
    <h1>KSMVC PVE T2 APT repository</h1>
    <p>Current metapackage version: ${kernel_version}</p>
    <p>See <a href="https://github.com/Ken5998/pve-edge-kernel-t2">the project on GitHub</a>.</p>
  </body>
</html>
EOF

aws s3 sync \
  "${repository_dir}/pool" \
  "s3://${bucket_name}/pool" \
  --endpoint-url "${r2_endpoint}" \
  --cache-control 'public,max-age=31536000,immutable' \
  --only-show-errors

aws s3 sync \
  "${repository_dir}/dists" \
  "s3://${bucket_name}/dists" \
  --endpoint-url "${r2_endpoint}" \
  --cache-control 'no-cache' \
  --only-show-errors

for repository_file in ksmvc-archive-keyring.gpg ksmvc-t2.sources index.html; do
  aws s3 cp \
    "${repository_dir}/${repository_file}" \
    "s3://${bucket_name}/${repository_file}" \
    --endpoint-url "${r2_endpoint}" \
    --cache-control 'no-cache' \
    --only-show-errors
done

echo "Published proxmox-kernel-t2 ${kernel_version} to https://apt.ksmvc.ch"
