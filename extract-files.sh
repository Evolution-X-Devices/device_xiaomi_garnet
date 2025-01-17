#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=garnet
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=
CARRIER_SKIP_FILES=()

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup)
            CLEAN_VENDOR=false
            ;;
        -k | --kang)
            KANG="--kang"
            ;;
        -s | --section)
            SECTION="${2}"
            shift
            CLEAN_VENDOR=false
            ;;
        *)
            SRC="${1}"
            ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        system_ext/lib64/libwfdmmsrc_system.so)
            [ "$2" = "" ] && return 0
            grep -q "libgui_shim.so" "${2}" || "${PATCHELF}" --add-needed "libgui_shim.so" "${2}"
            ;;
        system_ext/lib64/libwfdnative.so)
            [ "$2" = "" ] && return 0
            ${PATCHELF} --remove-needed "android.hidl.base@1.0.so" "${2}"
            grep -q "libbinder_shim.so" "${2}" || "${PATCHELF}" --add-needed "libbinder_shim.so" "${2}"
            grep -q "libinput_shim.so" "${2}" || "${PATCHELF}" --add-needed "libinput_shim.so" "${2}"
            ;;
        vendor/bin/hw/android.hardware.security.keymint-service-qti|vendor/lib/libqtikeymint.so|vendor/lib64/libqtikeymint.so)
            [ "$2" = "" ] && return 0
            grep -q "android.hardware.security.rkp-V3-ndk.so" "${2}" || "${PATCHELF_0_17_2}" --add-needed "android.hardware.security.rkp-V3-ndk.so" "${2}"
            ;;
        vendor/etc/camera/pureView_parameter.xml)
            [ "$2" = "" ] && return 0
            sed -i 's/=\([0-9]\+\)>/="\1">/g' "${2}"
            ;;
        vendor/etc/init/hw/init.batterysecret.rc|vendor/etc/init/hw/init.mi_thermald.rc|vendor/etc/init/hw/init.qti.kernel.rc)
            [ "$2" = "" ] && return 0
            sed -i 's/on charger/on property:init.svc.vendor.charger=running/g' "${2}"
			;;
		vendor/etc/media_codecs_parrot_v0.xml)
			[ "$2" = "" ] && return 0
			sed -i -E '/media_codecs_(google_audio|google_c2|google_telephony|vendor_audio)/d' "${2}"
			;;
		vendor/etc/vintf/manifest/c2_manifest_vendor.xml)
			[ "$2" = "" ] && return 0
			sed -ni '/dolby/!p' "${2}"
			;;
		vendor/etc/msm_irqbalance.conf)
			[ "$2" = "" ] && return 0
			sed -i "s/IGNORED_IRQ=27,23,38$/&,115,332/" "${2}"
			;;
		vendor/bin/hw/vendor.dolby.hardware.dms@2.0-service)
			[ "$2" = "" ] && return 0
			grep -q "libstagefright_foundation-v33.so" "${2}" || "${PATCHELF}" --add-needed "libstagefright_foundation-v33.so" "${2}"
			;;
		vendor/lib64/hw/audio.primary.parrot.so)
			[ "$2" = "" ] && return 0
			"${PATCHELF}" --replace-needed "libstagefright_foundation.so" "libstagefright_foundation-v33.so" "${2}"
			;;
		vendor/lib/libstagefright_soft_ddpdec.so|vendor/lib/libstagefrightdolby.so|vendor/lib64/libdlbdsservice.so|vendor/lib64/libstagefright_soft_ddpdec.so|vendor/lib64/libstagefrightdolby.so)
			[ "$2" = "" ] && return 0
            grep -q "libstagefright_foundation-v33.so" "${2}" || "${PATCHELF}" --replace-needed "libstagefright_foundation.so" "libstagefright_foundation-v33.so" "${2}"
            ;;
        vendor/lib/vendor.libdpmframework.so|vendor/lib64/vendor.libdpmframework.so)
            [ "$2" = "" ] && return 0
            grep -q "libhidlbase_shim.so" "${2}" || "${PATCHELF}" --add-needed "libhidlbase_shim.so" "${2}"
            ;;
        vendor/lib*/libwvhidl.so)
            [ "$2" = "" ] && return 0
            grep -q libcrypto_shim.so "${2}" || "${PATCHELF}" --add-needed "libcrypto_shim.so" "${2}"
            ;;            
        vendor/etc/seccomp_policy/atfwd@2.0.policy|vendor/etc/seccomp_policy/wfdhdcphalservice.policy|vendor/etc/seccomp_policy/sensors-qesdk.policy|vendor/etc/seccomp_policy/modemManager.policy)
        [ "$2" = "" ] && return 0
            grep -q "gettid: 1" "${2}" || echo -e "\ngettid: 1" >> "${2}"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

function blob_fixup_dry() {
    blob_fixup "$1" ""
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
