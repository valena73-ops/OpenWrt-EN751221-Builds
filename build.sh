#!/bin/sh
set -eu

REPO=https://github.com/cjdelisle/openwrt.git
HASH=ba9f212b567ee1cda360ba1fdb98629862ec974b

rm -rf ./openwrt
mkdir openwrt
cd openwrt
git init
git remote add origin "$REPO"
git fetch --depth 1 origin "$HASH"
git checkout "$HASH"

# The G-1425-MA has 256 MiB RAM. Adjust only the generic board's memory nodes.
DTS=target/linux/econet/dts/en751221_generic.dts
sed -i 's/reg = <0x00000000 0x4000000>;/reg = <0x00000000 0x10000000>;/' "$DTS"
sed -i 's/linux,usable-memory-range = <0x00020000 0x3fe0000>;/linux,usable-memory-range = <0x00020000 0x0ffe0000>;/' "$DTS"
grep -q 'reg = <0x00000000 0x10000000>;' "$DTS"
grep -q 'linux,usable-memory-range = <0x00020000 0x0ffe0000>;' "$DTS"

# Experimental PCIe enablement to let the mt7603/mt76x2 drivers probe the radios.
# No synthetic Wi-Fi calibration is copied from another board.
cat >> "$DTS" <<'EOF'

&pcie0 {
	status = "okay";
	econet,en751221-port0-quirks;
	econet,en751221-scu = <&scuclk>;
};

&pcie1 {
	status = "okay";
};
EOF

./scripts/feeds update -a
./scripts/feeds install -a

echo '
CONFIG_TARGET_econet=y
CONFIG_TARGET_econet_en751221=y
CONFIG_TARGET_MULTI_PROFILE=y
CONFIG_TARGET_DEVICE_econet_en751221_DEVICE_chinamobile_gs3101=y
CONFIG_TARGET_DEVICE_PACKAGES_econet_en751221_DEVICE_chinamobile_gs3101=""
CONFIG_TARGET_DEVICE_econet_en751221_DEVICE_en751221_generic=y
CONFIG_TARGET_DEVICE_PACKAGES_econet_en751221_DEVICE_en751221_generic=""
CONFIG_TARGET_DEVICE_econet_en751221_DEVICE_huawei_hg2821t-u=y
CONFIG_TARGET_DEVICE_PACKAGES_econet_en751221_DEVICE_huawei_hg2821t-u=""
CONFIG_TARGET_DEVICE_econet_en751221_DEVICE_nokia_g240g-e=y
CONFIG_TARGET_DEVICE_PACKAGES_econet_en751221_DEVICE_nokia_g240g-e=""
CONFIG_TARGET_DEVICE_econet_en751221_DEVICE_smartfiber_xp8421-b=y
CONFIG_TARGET_DEVICE_PACKAGES_econet_en751221_DEVICE_smartfiber_xp8421-b=""
CONFIG_TARGET_DEVICE_econet_en751221_DEVICE_tplink_archer-vr1200v-v2=y
CONFIG_TARGET_DEVICE_PACKAGES_econet_en751221_DEVICE_tplink_archer-vr1200v-v2=""
CONFIG_TARGET_DEVICE_econet_en751221_DEVICE_zyxel_pmg5617ga=y
CONFIG_TARGET_DEVICE_PACKAGES_econet_en751221_DEVICE_zyxel_pmg5617ga=""
CONFIG_TARGET_PER_DEVICE_ROOTFS=y
CONFIG_FEED_luci=y
CONFIG_FEED_packages=y
CONFIG_FEED_routing=y
CONFIG_FEED_telephony=y
CONFIG_FEED_video=y
CONFIG_IMAGEOPT=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_kmod-crypto-sha256=y
CONFIG_PACKAGE_kmod-econet-eth=y
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_kmod-fs-vfat=y
CONFIG_PACKAGE_kmod-gpio-button-hotplug=y
CONFIG_PACKAGE_kmod-lib-crc16=y
CONFIG_PACKAGE_kmod-libphy=y
CONFIG_PACKAGE_kmod-mii=y
CONFIG_PACKAGE_kmod-nls-base=y
CONFIG_PACKAGE_kmod-nls-cp437=y
CONFIG_PACKAGE_kmod-nls-iso8859-1=y
CONFIG_PACKAGE_kmod-nls-utf8=y
CONFIG_PACKAGE_kmod-scsi-core=y
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_kmod-usb-common=y
CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb-net-rtl8152=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-mac80211=y
CONFIG_PACKAGE_kmod-mt76-core=y
CONFIG_PACKAGE_kmod-mt7603=y
CONFIG_PACKAGE_kmod-mt76x02-common=y
CONFIG_PACKAGE_kmod-mt76x2-common=y
CONFIG_PACKAGE_kmod-mt76x2=y
CONFIG_PACKAGE_mt76-firmware=y
CONFIG_PACKAGE_iw=y
CONFIG_PACKAGE_wpad-basic-mbedtls=y
CONFIG_PACKAGE_nand-utils=y
CONFIG_PACKAGE_libatomic=y
CONFIG_PACKAGE_libpthread=y
CONFIG_PACKAGE_librt=y
CONFIG_PACKAGE_libstdcpp=y
CONFIG_PACKAGE_r8152-firmware=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
# CONFIG_TARGET_ROOTFS_INITRAMFS is not set
' > .config

make defconfig
# This build targets persistent SquashFS/TCLinux flash images, not initramfs.
# The pinned source has no ported GPON/xPON MAC + optical-front-end driver
# for Nokia G-1425-MA; optical service is not claimed to work in this build.
echo "NOTE: GPON/xPON driver is not enabled in this RAM test image; see build log."

make "-j$(nproc)" V=s

# Require the persistent TCLinux image that the device rescue page can accept.
test -s ./bin/targets/econet/en751221/openwrt-econet-en751221-nokia_g240g-e-squashfs-tclinux.trx
sha256sum ./bin/targets/econet/en751221/openwrt-econet-en751221-nokia_g240g-e-squashfs-tclinux.trx

# Rename generated images to the stable naming convention used by this repo.
cd ./bin/targets/econet/en751221
ls | sed -n -e 's/openwrt-snapshot-\(.*\)-econet-\(.*\)/mv openwrt-snapshot-\1-econet-\2 openwrt-econet-\2/p' | sh
