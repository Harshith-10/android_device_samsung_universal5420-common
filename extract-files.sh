#!/bin/bash
#
# Copyright (C) 2018-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE_COMMON=universal5420-common
VENDOR=samsung

# Load extractutils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; fi

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

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

# Initialize the helper
setup_vendor "${DEVICE_COMMON}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

# Fix proprietary blobs
BLOB_ROOT="$ANDROID_ROOT"/vendor/"$VENDOR"/"$DEVICE_COMMON"/proprietary
sed -i 's|EGL_KHR_surfaceless_context|EGL_HAX_surfaceless_context|g' $BLOB_ROOT/vendor/lib/egl/libGLES_mali.so

# Remove troublesome symbol from mali lib

# Update trustlets location
sed -i 's|system/app|vendor/app|g' $BLOB_ROOT/vendor/bin/mcDriverDaemon

# Mali blobs needs arm libm intrinsics deprecated in Q
patchelf --replace-needed libm.so libw.so $BLOB_ROOT/vendor/lib/egl/libGLES_mali.so


# Replace protobuf with vndk29 compat libs for specified libs
"${PATCHELF}" --replace-needed libprotobuf-cpp-lite.so libprotobuf-cpp-lite-v29.so $BLOB_ROOT/vendor/lib/libMcClient.so

"${MY_DIR}/setup-makefiles.sh"
