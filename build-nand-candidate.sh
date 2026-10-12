#!/bin/sh
set -eu

REPO=https://github.com/cjdelisle/openwrt.git
HASH=ba9f212b567ee1cda360ba1fdb98629862ec974b

rm -rf openwrt
mkdir openwrt
cd openwrt
git init
git remote add origin "$REPO"
git fetch --depth 1 origin "$HASH"
git checkout --detach "$HASH"

sed -i 's/0x4000000/0x10000000/' target/linux/econet/dts/en751221_generic.dts
sed -i 's/0x3fe0000/0x0ffe0000/' target/linux/econet/dts/en751221_generic.dts

python3 - <<'PY'
from pathlib import Path
p = Path("target/linux/econet/image/en751221.mk")
s = p.read_text()
needle = """define Device/en751221_generic
  DEVICE_VENDOR := EN751221 Family
  DEVICE_MODEL := Initramfs Image
  DEVICE_TITLE := EN751221 Initramfs Image
  DEVICE_DESCRIPTION := In-memory build for testing and recovery of EN751221 SoCs
  DEVICE_DTS := en751221_generic
endef"""
replacement = """define Device/en751221_generic
  DEVICE_VENDOR := EN751221 Family
  DEVICE_MODEL := Initramfs TRX Test
  DEVICE_TITLE := EN751221 Initramfs TRX Test
  DEVICE_DESCRIPTION := Experimental boot test; not a device-validated NAND firmware
  DEVICE_DTS := en751221_generic
  KERNEL_INITRAMFS := kernel-bin | append-dtb
  IMAGES := tclinux.trx
  IMAGE/tclinux.trx := append-kernel | lzma | tclinux-trx
  DEVICE_PACKAGES := kmod-usb3 kmod-mt7603 kmod-mt76x2
endef"""
if needle not in s:
    raise SystemExit("Generic profile did not match; stop.")
p.write_text(s.replace(needle, replacement, 1))
PY

./scripts/feeds update -a
./scripts/feeds install -a

cat > .config <<'EOF'
CONFIG_TARGET_econet=y
CONFIG_TARGET_econet_en751221=y
CONFIG_TARGET_MULTI_PROFILE=y
CONFIG_TARGET_DEVICE_econet_en751221_DEVICE_en751221_generic=y
CONFIG_TARGET_DEVICE_PACKAGES_econet_en751221_DEVICE_en751221_generic="kmod-usb3 kmod-mt7603 kmod-mt76x2"
CONFIG_TARGET_PER_DEVICE_ROOTFS=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_TARGET_ROOTFS_INITRAMFS=y
CONFIG_TARGET_INITRAMFS_COMPRESSION_NONE=y
CONFIG_FEED_luci=y
CONFIG_FEED_packages=y
CONFIG_FEED_routing=y
CONFIG_FEED_telephony=y
CONFIG_FEED_video=y
CONFIG_IMAGEOPT=y
CONFIG_PACKAGE_kmod-econet-eth=y
CONFIG_PACKAGE_kmod-usb-common=y
CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-usb3=y
CONFIG_PACKAGE_kmod-mt7603=y
CONFIG_PACKAGE_kmod-mt76x2=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_wpad-basic-mbedtls=y
EOF

make defconfig
make "-j$(nproc)" V=s

mkdir -p ../candidate-output
find bin/targets/econet/en751221 -maxdepth 1 -type f -name '*generic*' -size +1M -exec cp -v {} ../candidate-output/ \;
find ../candidate-output -type f -size +1M | grep . || { echo "No generic image produced" >&2; exit 1; }
cd ..
sha256sum candidate-output/* > candidate-output/SHA256SUMS
