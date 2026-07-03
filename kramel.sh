#!/usr/bin/bash
# Written by: cyberknight777
# YAKB v1.0
# Copyright (c) 2022-2023 Cyber Knight <cyberknight755@gmail.com>
#
#			GNU GENERAL PUBLIC LICENSE
#			 Version 3, 29 June 2007
#
# Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
# Everyone is permitted to copy and distribute verbatim copies
# of this license document, but changing it is not allowed.

# Some Placeholders: [!] [*] [✓] [✗]

# Default defconfig to use for builds.
export CONFIG=nethunter_defconfig

# Default directory where kernel is located in.
KDIR=$(pwd)
export KDIR

# Device name.
export DEVICE="Samsung Tab A6"

# Device codename.
export CODENAME="gtaxllte"

# Builder name.
export BUILDER="MrR0b0X"

# Kernel repository URL.
export REPO_URL="https://github.com/MrR0b0X/Nethunter_kernel_samsung_exynos7870"

# Commit hash of HEAD.
COMMIT_HASH=$(git rev-parse --short HEAD)
export COMMIT_HASH

# Telegram Information. Set 1 to enable. | Set 0 to disable.
export TGI=1
export CHATID=-1001763166286

# Necessary variables to be exported.
export ci
export version

# Number of jobs to run.
PROCS=$(nproc --all)
export PROCS

# Flag: set to 1 if "hdr" is passed as an argument.
HEADERS=0
for _a in "$@"; do [[ "$_a" == "hdr" ]] && HEADERS=1; done
export HEADERS

# Compiler to use for builds.
export COMPILER=gcc

# Module building support. Set 1 to enable. | Set 0 to disable.
export MODULE=0

# Requirements
if [ "${ci}" != 1 ]; then
    if ! hash dialog make curl wget unzip find 2>/dev/null; then
        echo -e "\n\e[1;31m[✗] Install dialog, make, curl, wget, unzip, and find! \e[0m"
        exit 1
    fi
fi

if [[ "${COMPILER}" = gcc ]]; then
    if [ ! -d "${KDIR}/gcc64" ]; then
        wget -O 64.tar.xz https://developer.arm.com/-/cdn-downloads/permalink/legacy-linaro-gnu-toolchains/4.9-2016.02/gcc-linaro-4.9-2016.02-x86_64_aarch64-linux-gnu.tar.xz && tar -xf 64.tar.xz
        mv "${KDIR}"/gcc-linaro-4.9-2016.02-x86_64_aarch64-linux-gnu "${KDIR}"/gcc64 && rm -rf 64.tar.xz
    fi

    KBUILD_COMPILER_STRING=$("${KDIR}"/gcc64/bin/aarch64-linux-gnu-gcc --version | head -n 1)
    export KBUILD_COMPILER_STRING
    export PATH="${KDIR}"/gcc64/bin:/usr/bin/:${PATH}
    export ANDROID_MAJOR_VERSION=o
    MAKE+=(
        ARCH=arm64
        O=out
	LD_LIBRARY_PATH="${KDIR}"/gcc64/bin:/$LD_LIBRARY_PATH
        CROSS_COMPILE=aarch64-linux-gnu-
    )

elif [[ "${COMPILER}" = clang ]]; then
    if [ ! -d "${KDIR}/clang" ]; then
       mkdir clang;wget -O clang.tar.gz https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/android-12.0.0_r12/clang-r416183b1.tar.gz;tar -xf clang.tar.gz -C clang;rm -rf clang.tar.gz;git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 arm64;git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 arm 
    fi

    KBUILD_COMPILER_STRING=$("${KDIR}"/clang/bin/clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')
    export KBUILD_COMPILER_STRING
    export PATH=$KDIR/clang/bin/:$KDIR/arm64/bin:$KDIR/arm/bin:/usr/bin/:${PATH}
    MAKE+=(
        ARCH=arm64
        O=out
        CROSS_COMPILE=aarch64-linux-android-
        CROSS_COMPILE_ARM32=arm-linux-androideabi-
        CLANG_TRIPLE=aarch64-linux-gnu-
        CC=${KDIR}/clang/bin/clang 
    )
fi

if [[ "${MODULE}" = 1 ]]; then
    if [ ! -d "${KDIR}"/modules ]; then
        git clone --depth=1 https://github.com/MrR0b0X/nethunter-modules "${KDIR}"/modules
    fi
fi

if [ ! -d "${KDIR}/anykernel3/" ]; then
    git clone --depth=1 https://github.com/MrR0b0X/anykernel3 -b gtaxllte anykernel3
fi

if [ "${ci}" != 1 ]; then
    if [ -z "${kver}" ]; then
        echo -ne "\e[1mEnter kver: \e[0m"
        read -r kver
    else
        export KBUILD_BUILD_VERSION=${kver}
    fi

    if [ -z "${zipn}" ]; then
        echo -ne "\e[1mEnter zipname: \e[0m"
        read -r zipn
    fi

else
    export KBUILD_BUILD_VERSION=${kver}
    export KBUILD_BUILD_HOST="builder"
    export KBUILD_BUILD_USER="MrR0b0X"
    export VERSION=$version
    kver=$KBUILD_BUILD_VERSION
    zipn=Nethunter-gtaxllte-${VERSION}
    if [[ "${MODULE}" = "1" ]]; then
        modn="${zipn}-modules"
    fi
fi

# A function to exit on SIGINT.
exit_on_signal_SIGINT() {
    echo -e "\n\n\e[1;31m[✗] Received INTR call - Exiting...\e[0m"
    exit 0
}
trap exit_on_signal_SIGINT SIGINT

# A function to send message(s) via Telegram's BOT api.
tg() {
    curl -sX POST https://api.telegram.org/bot"${TOKEN}"/sendMessage \
        -d chat_id="${CHATID}" \
        -d parse_mode=Markdown \
        -d disable_web_page_preview=true \
        -d text="$1" &>/dev/null
}

# A function to send file(s) via Telegram's BOT api.
tgs() {
    MD5=$(md5sum "$1" | cut -d' ' -f1)
    curl -fsSL -X POST -F document=@"$1" https://api.telegram.org/bot"${TOKEN}"/sendDocument \
        -F "chat_id=${CHATID}" \
        -F "parse_mode=Markdown" \
        -F "caption=$2 | *MD5*: \`$MD5\`"
}

# A function to clean kernel source prior building.
clean() {
    echo -e "\n\e[1;93m[*] Cleaning source and out/ directory! \e[0m"
    make clean && make mrproper && rm -rf "${KDIR}"/out
    echo -e "\n\e[1;32m[✓] Source cleaned and out/ removed! \e[0m"
}

# A function to regenerate defconfig.
rgn() {
    echo -e "\n\e[1;93m[*] Regenerating defconfig! \e[0m"
    make "${MAKE[@]}" $CONFIG
    cp -rf "${KDIR}"/out/.config "${KDIR}"/arch/arm64/configs/$CONFIG
    echo -e "\n\e[1;32m[✓] Defconfig regenerated! \e[0m"
}

# A function to open a menu based program to update current config.
mcfg() {
    rgn
    echo -e "\n\e[1;93m[*] Making Menuconfig! \e[0m"
    make "${MAKE[@]}" menuconfig
    cp -rf "${KDIR}"/out/.config "${KDIR}"/arch/arm64/configs/$CONFIG
    echo -e "\n\e[1;32m[✓] Saved Modifications! \e[0m"
}

# A function to build the kernel.
img() {
    if [[ "${TGI}" != "0" ]]; then
        tg "
*Build Number*: \`${kver}\`
*Builder*: \`${BUILDER}\`
*Core count*: \`$(nproc --all)\`
*Device*: \`${DEVICE} [${CODENAME}]\`
*Kernel Version*: \`$(make kernelversion 2>/dev/null)\`
*Date*: \`$(date)\`
*Zip Name*: \`${zipn}\`
*Compiler*: \`${KBUILD_COMPILER_STRING}\`
*Branch*: \`$(git rev-parse --abbrev-ref HEAD)\`
*Last Commit*: [${COMMIT_HASH}](${REPO_URL}/commit/${COMMIT_HASH})
"
    fi
    if [[ "${TGI}" != "0" ]]; then
        tg "*Building Kernel!*"
    fi
    rgn
    echo -e "\n\e[1;93m[*] Building Kernel! \e[0m"
    BUILD_START=$(date +"%s")
    time make -j"$PROCS" "${MAKE[@]}" Image 2>&1 | tee log.txt
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    if [ -f "${KDIR}/out/arch/arm64/boot/Image" ]; then
        if [[ "${SILENT}" != "1" ]]; then
            tg "*Kernel Built after $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)*"
        fi
        echo -e "\n\e[1;32m[✓] Kernel built after $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! \e[0m"
    else
        if [[ "${TGI}" != "0" ]]; then
            tgs "log.txt" "*Build failed*"
        fi
        echo -e "\n\e[1;31m[✗] Build Failed! \e[0m"
        exit 1
    fi
}

# A function to build DTBs.
dtb() {
    if [[ "${TGI}" != "0" ]]; then
        tg "*Building DTBs!*"
    fi
    rgn
    echo -e "\n\e[1;93m[*] Building DTBS! \e[0m"
    time make -j"$PROCS" "${MAKE[@]}" dtbs dtb.img
    echo -e "\n\e[1;32m[✓] Built DTBS! \e[0m"
}

# A function to build out-of-tree modules.
mod() {
    if [[ "${TGI}" != "0" ]]; then
        tg "*Building Modules!*"
    fi
    rgn
    echo -e "\n\e[1;93m[*] Building Modules! \e[0m"
    mkdir -p "${KDIR}"/out/modules
    make "${MAKE[@]}" modules_prepare
    make -j"$PROCS" "${MAKE[@]}" modules INSTALL_MOD_PATH="${KDIR}"/out/modules
    make "${MAKE[@]}" modules_install INSTALL_MOD_PATH="${KDIR}"/out/modules
    find "${KDIR}"/out/modules -type f -iname '*.ko' -exec cp {} "${KDIR}"/modules/system/lib/modules/ \;
    cd "${KDIR}"/modules || exit 1
    zip -r9 "${modn}".zip . -x ".git*" -x "README.md" -x "LICENSE" -x "*.zip"
    cd ../
    echo -e "\n\e[1;32m[✓] Built Modules! \e[0m"
}

# A function to build kernel headers
hdr() {
    if [[ "${TGI}" != "0" ]]; then
        tg "*Building Kernel Headers!*"
    fi
    rgn
    echo -e "\n\e[1;94m[*] Building Kernel Headers \e[0m"

    local arch
    arch="$(printf "%s\n" "${MAKE[@]}" | awk -F= '/^ARCH=/{print $2}')"

    local ver codename pkgname
    ver="$(grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL)' Makefile | awk '{print $3}' | paste -sd.)"
    codename="${CODENAME}"
    pkgname="linux-headers-${ver}-${codename}.deb"

    local pkgdir="${KDIR}/deb-pkg"
    local hdrdir="${pkgdir}/usr/src/linux-headers-${ver}-${codename}"
    rm -rf "${pkgdir}"
    mkdir -p "${pkgdir}/DEBIAN"
    mkdir -p "${hdrdir}"

    # ------------------------------------------------------------------
    # Step 1: Set up ARM64 OpenSSL and libyaml headers/libraries
    # ------------------------------------------------------------------
    local SYSROOT="${KDIR}/arm64-sysroot"
    mkdir -p "${SYSROOT}"

    # --- OpenSSL ---
    local OPENSSL_DEV_PKG="libssl-dev_3.0.2-0ubuntu1_arm64.deb"
    local OPENSSL_URL="http://ports.ubuntu.com/pool/main/o/openssl/${OPENSSL_DEV_PKG}"
    local SSL_SENTINEL="${SYSROOT}/.openssl_ready"

    if [ ! -f "${SSL_SENTINEL}" ]; then
        echo -e "\n\e[1;93m[*] Setting up ARM64 OpenSSL in ${SYSROOT} ...\e[0m"
        pushd "${SYSROOT}" >/dev/null || exit 1
        if [ ! -f "${OPENSSL_DEV_PKG}" ]; then
            wget "${OPENSSL_URL}" || {
                echo -e "\e[1;31m[✗] Failed to download ${OPENSSL_DEV_PKG}\e[0m"
                exit 1
            }
        fi
        dpkg-deb -x "${OPENSSL_DEV_PKG}" .
        touch "${SSL_SENTINEL}"
        popd >/dev/null || exit 1
    fi

    # --- libyaml ---
    local YAML_DEV_PKG="libyaml-dev_0.2.5-2_arm64.deb"
    local YAML_URL="http://ports.ubuntu.com/pool/main/liby/libyaml/${YAML_DEV_PKG}"
    local YAML_SENTINEL="${SYSROOT}/.libyaml_ready"

    if [ ! -f "${YAML_SENTINEL}" ]; then
        echo -e "\n\e[1;93m[*] Setting up ARM64 libyaml-dev in ${SYSROOT} ...\e[0m"
        pushd "${SYSROOT}" >/dev/null || exit 1
        if [ ! -f "${YAML_DEV_PKG}" ]; then
            wget "${YAML_URL}" || {
                echo -e "\e[1;31m[✗] Failed to download ${YAML_DEV_PKG}\e[0m"
                exit 1
            }
        fi
        dpkg-deb -x "${YAML_DEV_PKG}" .
        touch "${YAML_SENTINEL}"
        popd >/dev/null || exit 1
    fi

    # Flags for host tools (OpenSSL + libyaml)
    local HOST_CFLAGS="-I${SYSROOT}/usr/include -I${SYSROOT}/usr/include/aarch64-linux-gnu"
    local HOST_LDFLAGS="-L${SYSROOT}/usr/lib/aarch64-linux-gnu"

    # ------------------------------------------------------------------
    # Step 2: Prepare the kernel build tree and cross‑compile host tools
    # ------------------------------------------------------------------

    echo -e "\n\e[1;93m[*] Running prepare + modules_prepare with out/ \e[0m"

    # Override HOSTCC, HOSTCXX to build scripts/ binaries for aarch64
    make O=out ARCH=arm64 \
         CROSS_COMPILE=/usr/bin/aarch64-linux-gnu- \
         CC=/usr/bin/aarch64-linux-gnu-gcc \
         LD=/usr/bin/aarch64-linux-gnu-ld \
         AS=/usr/bin/aarch64-linux-gnu-as \
         AR=/usr/bin/aarch64-linux-gnu-ar \
         NM=/usr/bin/aarch64-linux-gnu-nm \
         STRIP=/usr/bin/aarch64-linux-gnu-strip \
         OBJCOPY=/usr/bin/aarch64-linux-gnu-objcopy \
         OBJDUMP=/usr/bin/aarch64-linux-gnu-objdump \
         HOSTCC="/usr/bin/aarch64-linux-gnu-gcc -static ${HOST_CFLAGS} ${HOST_LDFLAGS}" \
         HOSTCXX="/usr/bin/aarch64-linux-gnu-g++ -static ${HOST_CFLAGS} ${HOST_LDFLAGS}" \
         HOSTLD=/usr/bin/aarch64-linux-gnu-ld \
         HOSTLDFLAGS="" HOSTCFLAGS="" \
         olddefconfig prepare modules_prepare

    # ------------------------------------------------------------------
    # Step 3: Collect source-tree files
    # ------------------------------------------------------------------
    echo -e "\n\e[1;93m[*] Collecting source tree files \e[0m"
    (cd "${KDIR}" && find . \
        \( -name "Makefile*" -o -name "Kconfig*" -o -name "*.pl" \) \
        -not \( -path "./out/*" -o -path "./deb-pkg/*" -o -path "./.git/*" \) \
        -type f \
        | tar --no-recursion -T - -cf - \
    ) | tar -xf - -C "${hdrdir}"

    (cd "${KDIR}" && find scripts -name "*.sh" -type f \
        | tar --no-recursion -T - -cf - \
    ) | tar -xf - -C "${hdrdir}"

    (cd "${KDIR}" && find arch/*/include -type f \
        | tar --no-recursion -T - -cf - \
    ) | tar -xf - -C "${hdrdir}"

    (cd "${KDIR}" && find "arch/${arch}" \
        \( -name "module.lds" -o -name "Kbuild.platforms" -o -name "Platform" \) \
        -type f \
        | tar --no-recursion -T - -cf - \
    ) | tar -xf - -C "${hdrdir}"

    (cd "${KDIR}" && find include -type f \
        | tar --no-recursion -T - -cf - \
    ) | tar -xf - -C "${hdrdir}"

    (cd "${KDIR}" && find scripts -type f \
        | tar --no-recursion -T - -cf - \
    ) | tar -xf - -C "${hdrdir}"

    if [ -d "${KDIR}/security" ]; then
        (cd "${KDIR}" && find security -type f \
            | tar --no-recursion -T - -cf - \
        ) | tar -xf - -C "${hdrdir}"
    fi

    if [ -d "${KDIR}/tools" ]; then
        (cd "${KDIR}" && find tools -type f \
            | tar --no-recursion -T - -cf - \
        ) | tar -xf - -C "${hdrdir}"
    fi

    if [ -d "${KDIR}/techpack" ]; then
        (cd "${KDIR}" && find techpack \
            \( -name "Makefile*" -o -name "Kconfig*" \) \
            -type f \
            | tar --no-recursion -T - -cf - \
        ) | tar -xf - -C "${hdrdir}"
    fi

    # ------------------------------------------------------------------
    # Step 4: Collect build-tree (out/) generated files
    # ------------------------------------------------------------------
    echo -e "\n\e[1;93m[*] Collecting out/ (objtree) generated files \e[0m"
    (cd "${KDIR}/out" && find include -type f \
        | tar --no-recursion -T - -cf - \
    ) | tar -xf - -C "${hdrdir}"

    (cd "${KDIR}/out" && find "arch/${arch}/include" -type f \
        | tar --no-recursion -T - -cf - \
    ) | tar -xf - -C "${hdrdir}"

    if [ -d "${KDIR}/out/scripts" ]; then
        (cd "${KDIR}/out" && find scripts -type f \
            | tar --no-recursion -T - -cf - \
        ) | tar -xf - -C "${hdrdir}"
    fi

    touch "${hdrdir}/Module.symvers"
    if [ -f "${KDIR}/out/Module.symvers" ]; then
        cp "${KDIR}/out/Module.symvers" "${hdrdir}/Module.symvers"
    fi

    if [ -f "${KDIR}/out/.config" ]; then
        cp "${KDIR}/out/.config" "${hdrdir}/.config"
    fi

    if [ -f "${KDIR}/out/include/config/kernel.release" ]; then
        mkdir -p "${hdrdir}/include/config"
        cp "${KDIR}/out/include/config/kernel.release" \
           "${hdrdir}/include/config/kernel.release"
    fi

    # ------------------------------------------------------------------
    # Step 5: Remove all pre-compiled host binaries (*.o and *.cmd)
    # ------------------------------------------------------------------
    echo -e "\n\e[1;93m[*] Removing host-arch object files and cmd caches \e[0m"
    find "${hdrdir}" -type f \( -name "*.o" -o -name "*.cmd" \) -delete

    # ------------------------------------------------------------------
    # Step 6: Create symlink for arch/aarch64 -> arch/arm64
    # ------------------------------------------------------------------
    if [ ! -e "${hdrdir}/arch/arm64/aarch64" ]; then
        ln -sf "${hdrdir}/arch/${arch}" "${hdrdir}/arch/aarch64"
    fi

    # ------------------------------------------------------------------
    # Step 7: Generate DEBIAN maintainer scripts
    # ------------------------------------------------------------------
    cat > "${pkgdir}/DEBIAN/postinst" << POSTINST_EOF
#!/bin/sh
set -e
HEADERS_DIR="/usr/src/linux-headers-${ver}-${codename}"
KREL="\$(uname -r)"
MODULES_DIR="/lib/modules/\${KREL}"

echo "Kernel headers: creating build symlink ..."
mkdir -p "\${MODULES_DIR}"
ln -sf "\${HEADERS_DIR}" "\${MODULES_DIR}/build"
echo "Created symlink \${MODULES_DIR}/build -> \${HEADERS_DIR}"
exit 0
POSTINST_EOF
    chmod 755 "${pkgdir}/DEBIAN/postinst"

    cat > "${pkgdir}/DEBIAN/prerm" << PRERM_EOF
#!/bin/sh
set -e
HEADERS_DIR="/usr/src/linux-headers-${ver}-${codename}"
KREL="\$(uname -r)"
LINK="/lib/modules/\${KREL}/build"

if [ -L "\${LINK}" ]; then
    rm -f "\${LINK}"
    echo "Removed symlink \${LINK}"
fi

if [ -d "\${HEADERS_DIR}" ]; then
    rm -rf "\${HEADERS_DIR}"
    echo "Removed headers directory \${HEADERS_DIR}"
fi
exit 0
PRERM_EOF
    chmod 755 "${pkgdir}/DEBIAN/prerm"

    cat > "${pkgdir}/DEBIAN/control" << CONTROL_EOF
Package: linux-headers-${ver}-${codename}
Version: ${ver}
Architecture: ${arch}
Maintainer: ${BUILDER}
Description: Full kernel headers for ${ver} (${codename})
 This package provides the complete set of kernel headers required
 for building out-of-tree kernel modules against arm/arm64 devices.
CONTROL_EOF

    # ------------------------------------------------------------------
    # Step 8: Build the .deb package
    # ------------------------------------------------------------------
    echo -e "\n\e[1;93m[*] Building .deb package \e[0m"
    fakeroot dpkg-deb --build "${pkgdir}" "${KDIR}/${pkgname}"

    echo -e "\n\e[1;32m[✓] Kernel Headers built: ${pkgname} \e[0m"
    if [[ "${HEADERS}" == "1" ]]; then
        tgs linux-headers-*.deb "*#${kver} ${KBUILD_COMPILER_STRING}*"
    fi
} 

# A function to build an AnyKernel3 zip.
mkzip() {
    if [[ "${TGI}" != "0" ]]; then
        tg "*Building zip!*"
    fi
    echo -e "\n\e[1;93m[*] Building zip! \e[0m"
    cp -p "${KDIR}"/out/arch/arm64/boot/Image "${KDIR}"/anykernel3
    cp -p "${KDIR}"/out/arch/arm64/boot/dtb.img "${KDIR}"/anykernel3
    cd "${KDIR}"/anykernel3 || exit 1
    zip -r9 "$zipn".zip . -x ".git*" -x "README.md" -x "LICENSE" -x "*.zip"
    echo -e "\n\e[1;32m[✓] Built zip! \e[0m"
    if [[ "${TGI}" != "0" ]]; then
        tgs "${zipn}.zip" "*#${kver} ${KBUILD_COMPILER_STRING}*"
    fi
    if [[ "${MODULE}" = "1" ]]; then
        cd ../modules || exit 1
        tgs "${modn}.zip" "*#${kver} ${KBUILD_COMPILER_STRING}*"
    fi
}

# A function to build specific objects.
obj() {
    rgn
    echo -e "\n\e[1;93m[*] Building ${1}! \e[0m"
    time make -j"$PROCS" "${MAKE[@]}" "$1"
    echo -e "\n\e[1;32m[✓] Built ${1}! \e[0m"
}

# A function to uprev localversion in defconfig.
upr() {
    echo -e "\n\e[1;93m[*] Bumping localversion to -MrR0b0X-${1}! \e[0m"
    "${KDIR}"/scripts/config --file "${KDIR}"/arch/arm64/configs/$CONFIG --set-str CONFIG_LOCALVERSION "-MrRobin_Ho_Od-${1}"
    rgn
    if [ "${ci}" != 1 ]; then
        git add arch/arm64/configs/$CONFIG
        git commit -S -s -m "nethunter_defconfig: Bump to \`${1}\`"
    fi
    echo -e "\n\e[1;32m[✓] Bumped localversion to -MrR0b0X-${1}! \e[0m"
}

# A function to showcase the options provided for args-based usage.
helpmenu() {
    echo -e "\n\e[1m
usage: kver=<version number> zipn=<zip name> $0 <arg>
example: $0 --kver=69 --zipn=Kernel-Beta mcfg
example: $0 --kver=420 --zipn=Kernel-Beta mcfg img
example: $0 --kver=69420 --zipn=Kernel-Beta mcfg img hdr mkzip
example: $0 --kver=1 --zipn=Kernel-Beta --obj=drivers/android/binder.o
example: $0 --kver=2 --zipn=Kernel-Beta --obj=kernel/sched/
example: $0 --kver=3 --zipn=Kernel-Beta--upr=r16
	 mcfg   Runs make menuconfig
	 img    Builds Kernel
	 dtb    Builds dtb(o).img
	 mod    Builds out-of-tree modules
	 hdr    Builds kernel headers
	 mkzip  Builds anykernel3 zip
	 --obj  Builds specific driver/subsystem
	 rgn    Regenerates defconfig
	 --upr  Uprevs kernel version in defconfig
	 --kver kernel buildversion
	 --zipn zip name
\e[0m"
}

# A function to setup menu-based usage.
ndialog() {
    HEIGHT=16
    WIDTH=40
    CHOICE_HEIGHT=30
    BACKTITLE="Yet Another Kernel Builder"
    TITLE="YAKB v1.0"
    MENU="Choose one of the following options: "
    OPTIONS=(1 "Build kernel"
        2 "Build DTBs"
        3 "Build modules"
	4 "Build kernel headers"
        5 "Open menuconfig"
        6 "Regenerate defconfig"
        7 "Uprev localversion"
        8 "Build AnyKernel3 zip"
        9 "Build a specific object"
        10 "Clean"
        11 "Exit"
    )
    CHOICE=$(dialog --clear \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --menu "$MENU" \
        $HEIGHT $WIDTH $CHOICE_HEIGHT \
        "${OPTIONS[@]}" \`
        2>&1 >/dev/tty)
    clear
    case "$CHOICE" in
    1)
        clear
        img
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    2)
        clear
        dtb
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    3)
        clear
        mod
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
	fi
	;;
    4)
        clear
        hdr
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    5)
        clear
        mcfg
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    6)
        clear
        rgn
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    7)
        dialog --inputbox --stdout "Enter version number: " 15 50 | tee .t
        ver=$(cat .t)
        clear
        upr "$ver"
        rm .t
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    8)
        mkzip
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    9)
        dialog --inputbox --stdout "Enter object path: " 15 50 | tee .f
        ob=$(cat .f)
        if [ -z "$ob" ]; then
            dialog --inputbox --stdout "Enter object path: " 15 50 | tee .f
        fi
        clear
        obj "$ob"
        rm .f
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    10)
        clear
        clean
        img
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    11)
        echo -e "\n\e[1m Exiting YAKB...\e[0m"
        sleep 3
        exit 0
        ;;
    esac
}

if [ "${ci}" == 1 ]; then
    upr "${version}"
fi

if [[ -z $* ]]; then
    ndialog
fi

for arg in "$@"; do
    case "${arg}" in
    "mcfg")
        mcfg
        ;;
    "img")
        img
        ;;
    "dtb")
        dtb
        ;;
    "mod")
        mod
        ;;
    "hdr")
	hdr
	;;
    "mkzip")
        mkzip
        ;;
    "--obj="*)
        object="${arg#*=}"
        if [[ -z "$object" ]]; then
            echo "Use --obj=filename.o"
            exit 1
        else
            obj "$object"
        fi
        ;;
    "rgn")
        rgn
        ;;
    "--upr="*)
        vers="${arg#*=}"
        if [[ -z "$vers" ]]; then
            echo "Use --upr=version"
            exit 1
        else
            upr "$vers"
        fi
        ;;
    "clean")
        clean
        ;;
    "help")
        helpmenu
        exit 1
        ;;
    *)
        helpmenu
        exit 1
        ;;
    esac
done
