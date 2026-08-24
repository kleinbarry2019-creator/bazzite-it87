#!/usr/bin/env bash

set -euo pipefail

cp -a /ctx/system_files/. /

# Keep the user's current system applications in the immutable image instead
# of depending on rpm-ostree layers that would disappear during the switch.
dnf5 install -y \
	chatgpt \
	coolercontrol \
	coolercontrold \
	displaylink \
	google-chrome-stable \
	liquidctl

mapfile -t module_files < <(
	find /usr/lib/modules -type f -path '*/updates/dkms/it87.ko.xz' -print
)

if [[ "${#module_files[@]}" -ne 1 ]]; then
	printf 'Expected exactly one IT87 module, found %s\n' \
		"${#module_files[@]}" >&2
	exit 1
fi

module_file="${module_files[0]}"
kernel_version="${module_file#/usr/lib/modules/}"
kernel_version="${kernel_version%%/*}"

if [[ ! -d "/usr/lib/modules/${kernel_version}/kernel" ]]; then
	printf 'IT87 was built for a kernel absent from the final image: %s\n' \
		"${kernel_version}" >&2
	exit 1
fi

module_vermagic="$(modinfo -F vermagic "${module_file}")"
if [[ "${module_vermagic%% *}" != "${kernel_version}" ]]; then
	printf 'IT87 vermagic mismatch: expected %s, got %s\n' \
		"${kernel_version}" "${module_vermagic}" >&2
	exit 1
fi

depmod -a "${kernel_version}"

selected_module="$(modinfo -k "${kernel_version}" -F filename it87)"
if [[ "${selected_module}" != "/lib/modules/${kernel_version}/updates/dkms/it87.ko.xz" ]]; then
	printf 'depmod selected the wrong IT87 module: %s\n' \
		"${selected_module}" >&2
	exit 1
fi

systemctl enable coolercontrold.service

printf 'Embedded IT87 module: %s\n' "${selected_module}"
printf 'IT87 vermagic: %s\n' "${module_vermagic}"
