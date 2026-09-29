

# Proxmox Edge kernels

Custom Linux kernels for Proxmox VE 9 - Fork to add support for T2 Macs.

The fork simply contains the CI setup to compile kernels using the scripts and documentation from [fabianishere/pve-edge-kernel](https://github.com/fabianishere/pve-edge-kernel), [proxmox/pve-kernel](https://github.com/proxmox/pve-kernel) and [additional patches](https://github.com/t2linux/linux-t2-patches) to support T2 Macs.

You should also refer to the [t2linux wiki](https://wiki.t2linux.org/) for help regarding miscellaneous topics related to T2 Macs.

Many people need control of fans for Proxmox, so I am linking the fan guide [here](https://wiki.t2linux.org/guides/fan/).

## Donations

I accept donations via [GitHub Sponsors](https://github.com/sponsors/Ken5998). If you wanna appreciate my work by donating, you can donate me via the methods above. **Your donations shall keep me motivated to maintain this repository.**

## Installation

These packages target Proxmox VE 9 on T2 Macs. Run the installation commands as
root on your Proxmox host. Choose either the APT repository for ongoing updates
or a manual download to install a specific release.

### APT repository

The signed APT repository automatically tracks the latest successfully built T2
kernel and headers through the `proxmox-kernel-t2` metapackage.
The setup commands require `curl` to be installed.

```bash
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://apt.ksmvc.ch/ksmvc-archive-keyring.gpg \
  -o /etc/apt/keyrings/ksmvc-archive-keyring.gpg
curl -fsSL https://apt.ksmvc.ch/ksmvc-t2.sources \
  -o /etc/apt/sources.list.d/ksmvc-t2.sources
apt update
apt install proxmox-kernel-t2
```

Future kernels and headers can then be installed with `apt full-upgrade`.
The repository signing-key fingerprint is
`6127 B3F9 ADD5 1419 7905 2C93 2313 B094 2151 808C`.

### Manual package installation

Download the T2 kernel and matching headers from the
[Releases](https://github.com/Ken5998/pve-edge-kernel-t2/releases) page into an
otherwise empty directory. From that directory, install them with:

```bash
apt install ./proxmox-kernel-*-pve-t2_*_amd64.deb ./proxmox-headers-*-pve-t2_*_amd64.deb
```

Manual installation does not configure the APT repository or install its
`proxmox-kernel-t2` metapackage. To receive future T2 releases through APT,
follow the repository setup above.

## Removal

Boot into a kernel you intend to keep before removing an older one. Check the
running kernel with `uname -r`, then use `apt` to remove the specific kernel and
headers packages. Replace `KERNEL_RELEASE` with the full release identifier
(for example, `7.0.14-20-pve-t2`):

```bash
apt remove proxmox-kernel-KERNEL_RELEASE proxmox-headers-KERNEL_RELEASE
```

If you installed `proxmox-kernel-t2`, it depends on the kernel and headers it
tracks. Removing those packages also requires removing the metapackage, which
stops it from pulling in future T2 releases.

## Building

### Building manually

To compile the kernel yourself, follow the source preparation and build steps
in the [CI workflow](.github/workflows/build.yml).

#### Prerequisites

The current workflow uses a Linux host with Docker and builds inside a
`debian:trixie` container. You also need Git to fetch the sources and enough disk
space for the kernel sources, build output and Debian packages. The workflow's
`Build Kernel` step installs the build dependencies inside the container;
refer to it for the complete package list and Proxmox repository setup.

Use the same pinned T2 patch revision and patch preparation steps as the
workflow. Newer upstream patches may not apply to the current Proxmox kernel.

### Automated builds

GitHub Actions is scheduled to check the current Proxmox kernel every Monday
at 03:17 UTC. If the corresponding T2 release tag already exists, the scheduled
run skips the build. Otherwise, it builds the Debian packages, publishes them
in [Releases](https://github.com/Ken5998/pve-edge-kernel-t2/releases) and updates
the signed APT repository.

The workflow also runs on pushes unless the commit message contains `skip ci`,
and can be started manually from the
[Actions page](https://github.com/Ken5998/pve-edge-kernel-t2/actions/workflows/build.yml).
Push and manual runs do not use the scheduled release-exists check.

## Credits
Following are the people/groups that made this fork possible and the links to contribute to them:
1. [AdityaGarg8](https://www.buymeacoffee.com/gargadityav)
2. [fabianishere](https://www.buymeacoffee.com/fabianishere)
3. [t2linux](https://wiki.t2linux.org/contribute/)

## Contributing
Questions, suggestions and contributions are welcome and appreciated!
You can contribute in various meaningful ways:

* Report a bug through [Github issues](https://github.com/Ken5998/pve-edge-kernel-t2/issues). Please report bugs only if you feel they are specific to T2 Macs. If your bug is something unrelated to T2 Macs and instead proxmox specific, I'd suggest you to report them to [fabianishere](https://github.com/fabianishere/pve-edge-kernel).
* Propose new patches and flavors for the project.
* Contribute improvements to the documentation.
* Provide feedback about how we can improve the project.
