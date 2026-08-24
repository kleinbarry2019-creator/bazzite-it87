#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ne 2 ]]; then
	echo 'Usage: build-it87.sh COMMIT VERSION' >&2
	exit 2
fi

it87_commit="$1"
it87_version="$2"

mapfile -t kernel_directories < <(
	find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -print
)

if [[ "${#kernel_directories[@]}" -ne 1 ]]; then
	printf 'Expected exactly one kernel in the Bazzite image, found %s\n' \
		"${#kernel_directories[@]}" >&2
	printf '%s\n' "${kernel_directories[@]}" >&2
	exit 1
fi

kernel_version="$(basename "${kernel_directories[0]}")"

dnf5 install -y \
	gcc \
	git-core \
	"kernel-devel-matched-${kernel_version}" \
	make \
	xz

git clone --filter=blob:none https://github.com/frankcrawford/it87.git /tmp/it87
git -C /tmp/it87 checkout --detach "${it87_commit}"

make -C /tmp/it87 \
	TARGET="${kernel_version}" \
	DRIVER_VERSION="${it87_version}" \
	modules

module_directory="/it87-root/usr/lib/modules/${kernel_version}/updates/dkms"
install -D -m 0644 /tmp/it87/it87.ko "${module_directory}/it87.ko"
xz -f -C crc32 "${module_directory}/it87.ko"

module_file="${module_directory}/it87.ko.xz"
module_vermagic="$(modinfo -F vermagic "${module_file}")"
if [[ "${module_vermagic%% *}" != "${kernel_version}" ]]; then
	printf 'Built IT87 vermagic mismatch: expected %s, got %s\n' \
		"${kernel_version}" "${module_vermagic}" >&2
	exit 1
fi

printf 'Built IT87 %s (%s) for %s\n' \
	"${it87_version}" "${it87_commit}" "${kernel_version}"
