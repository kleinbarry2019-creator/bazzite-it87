# Bazzite IT87 image

This custom bootc image derives from `bazzite-nvidia-open:stable` and embeds a
kernel-matched IT87 driver for the Gigabyte B550M S2H / ITE IT8688E. It also
installs CoolerControl, Liquidctl, DisplayLink, Google Chrome and the official
ChatGPT/Codex desktop app, and enables `coolercontrold.service`.

The tested driver revision is pinned to:

```text
490f76f61900c163fac5328506c49969bd716dc6
```

The build intentionally fails if:

- the Bazzite base contains an unexpected number of kernels;
- matching kernel development files are unavailable;
- the driver no longer compiles for the current Bazzite OGC kernel;
- the resulting module has incompatible `vermagic`; or
- `depmod` does not prefer the embedded module over the in-tree driver.

No fan or PWM values are configured by this image. The module is loaded during
boot and CoolerControl retains control of user-defined profiles.

## Publish with GitHub

1. Create an empty public GitHub repository named `bazzite-it87`.
2. If your GitHub account is not `kleinbarry2019-creator`, change
   `REPO_ORGANIZATION` in
   `image-template.env`.
3. Copy this project into that repository, commit it, and push the `main`
   branch.
4. Enable GitHub Actions. The workflow builds daily and publishes to
   `ghcr.io/<account>/bazzite-it87:latest`.
5. For signed releases, generate a Cosign key pair and add the private key as
   the GitHub Actions secret `SIGNING_SECRET`, following the Universal Blue
   image-template documentation. Never commit `cosign.key`.

Pull requests build and verify the image but do not publish it.

## One-time migration of the current installation

The new driver detected the IT8688E without module parameters. Before the first
boot into this image, preserve and disable the old forced-ID configuration:

```bash
sudo mv /etc/modprobe.d/it87.conf \
  /etc/modprobe.d/it87.conf.pre-bazzite-it87
```

Do not change or remove the unrelated broken `8812au` DKMS entry.

After the GitHub build succeeds, switch to the published image (replace the
account name if needed):

```bash
sudo bootc switch ghcr.io/kleinbarry2019-creator/bazzite-it87:latest
systemctl reboot
```

The original Bazzite deployment remains available for rollback through the
boot menu. Do not remove it until the checks below have passed.

## Verification after reboot

```bash
uname -r
modinfo -F filename it87
lsmod | grep '^it87'
cat /sys/class/hwmon/hwmon*/name
sudo dmesg | grep -iE 'it87|it8688'
systemctl --no-pager --full status coolercontrold.service
journalctl -u coolercontrold.service -b --no-pager | \
  grep -iE 'it87|it8688|error|fail|Initialization Complete'
```

`modinfo` must point to
`/lib/modules/<kernel>/updates/dkms/it87.ko.xz`, and the kernel log should
report an `IT8688E` at `0xa40`.

## Local checks

Repository syntax:

```bash
just check
shellcheck build_files/*.sh
```

Full image build (large download):

```bash
just build
```

## Updating IT87

Change both `IT87_COMMIT` and `IT87_VERSION` in `Containerfile`. Always test the
new image as a separate tag before making it the default.

## Secure Boot

The current target machine has Secure Boot disabled. The embedded out-of-tree
module is therefore intentionally not kernel-signed. If Secure Boot is enabled
later, the module must be signed with a key enrolled in the machine firmware;
container signing alone does not sign kernel modules.
