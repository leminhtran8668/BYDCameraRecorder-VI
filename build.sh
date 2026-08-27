#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_dir="${project_root}/build"
generated_dir="${build_dir}/generated"
stub_classes="${build_dir}/stub-classes"
app_classes="${build_dir}/app-classes"
vendor_jar="${project_root}/vendor/bmmcamera.jar"
phone_ui_root="${project_root}/phone-ui"
signing_mode="${BYD_CAMERA_SIGNING_MODE:-debug}"
release_signing_dir="${BYD_CAMERA_RELEASE_SIGNING_DIR:-${project_root}_build_secret}"
release_keystore="${release_signing_dir}/byd-camera-release.jks"
release_password_file="${release_signing_dir}/byd-camera-release.password"
release_key_alias="byd-camera-release"

# --------------------------------------------------------------------------
# Toolchain: bundled Linux tools → ANDROID_HOME / common SDK paths
# --------------------------------------------------------------------------
tool_bundle_root="${BYD_CAMERA_TOOLCHAIN_ROOT:-${project_root}/.tools}"
tool_root="${tool_bundle_root}/runtime"
java_home_bundle="${tool_bundle_root}/java-home"

USE_BUNDLE_TOOLCHAIN=false
if [[ -d "${tool_root}" && -d "${java_home_bundle}" ]]; then
    USE_BUNDLE_TOOLCHAIN=true
fi

if [[ "${USE_BUNDLE_TOOLCHAIN}" == "true" ]]; then
    android_jar="${BYD_CAMERA_ANDROID_JAR:-${tool_root}/usr/lib/android-sdk/platforms/android-23/android.jar}"
    build_tools_dir="${tool_root}/usr/lib/android-sdk/build-tools/debian"
    dx_jar="${BYD_CAMERA_DX_JAR:-${build_tools_dir}/lib/dx.jar}"
    d8_jar=""
    apksigner_jar="${BYD_CAMERA_APKSIGNER_JAR:-${tool_root}/usr/share/java/apksigner.jar}"
    export JAVA_HOME="${java_home_bundle}"
    export PATH="${java_home_bundle}/bin:${build_tools_dir}:${tool_root}/usr/bin:${PATH}"
    export LD_LIBRARY_PATH="${tool_root}/usr/lib/x86_64-linux-gnu/android:${tool_root}/usr/lib/x86_64-linux-gnu:${tool_root}/usr/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
else
    # Detect Android SDK (macOS + Linux common locations)
    ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
    if [[ -z "${ANDROID_SDK}" || ! -d "${ANDROID_SDK}" ]]; then
        for candidate in \
            "${HOME}/Library/Android/sdk" \
            "${HOME}/Android/Sdk" \
            /usr/lib/android-sdk \
            /opt/android-sdk; do
            if [[ -d "${candidate}" ]]; then
                ANDROID_SDK="${candidate}"
                break
            fi
        done
    fi
    if [[ -z "${ANDROID_SDK}" || ! -d "${ANDROID_SDK}" ]]; then
        printf 'Android SDK not found. Set ANDROID_HOME or install Android Studio / cmdline-tools.\n' >&2
        exit 1
    fi

    if [[ -n "${BYD_CAMERA_ANDROID_JAR:-}" ]]; then
        android_jar="${BYD_CAMERA_ANDROID_JAR}"
    else
        android_jar="$(find "${ANDROID_SDK}/platforms" -name "android.jar" 2>/dev/null | sort -V | tail -1)"
        if [[ -z "${android_jar}" ]]; then
            printf 'android.jar not found under %s/platforms. Install a platform package.\n' "${ANDROID_SDK}" >&2
            exit 1
        fi
    fi

    build_tools_dir="${BYD_CAMERA_BUILD_TOOLS_DIR:-$(find "${ANDROID_SDK}/build-tools" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -1)}"
    if [[ -z "${build_tools_dir}" || ! -d "${build_tools_dir}" ]]; then
        printf 'Android build-tools not found under %s/build-tools.\n' "${ANDROID_SDK}" >&2
        exit 1
    fi

    dx_jar=""
    if [[ -f "${build_tools_dir}/lib/d8.jar" ]]; then
        d8_jar="${build_tools_dir}/lib/d8.jar"
    elif [[ -f "${build_tools_dir}/lib/dx.jar" ]]; then
        dx_jar="${build_tools_dir}/lib/dx.jar"
        d8_jar=""
    else
        d8_jar=""
    fi
    apksigner_jar="${BYD_CAMERA_APKSIGNER_JAR:-${build_tools_dir}/lib/apksigner.jar}"
    if [[ ! -f "${apksigner_jar}" ]]; then
        # Some SDK layouts put apksigner as a binary wrapper
        if [[ -x "${build_tools_dir}/apksigner" ]]; then
            apksigner_cmd=("${build_tools_dir}/apksigner")
            apksigner_jar=""
        else
            printf 'apksigner not found in %s\n' "${build_tools_dir}" >&2
            exit 1
        fi
    fi
    export PATH="${build_tools_dir}:${PATH}"

    printf 'Android SDK: %s\n' "${ANDROID_SDK}"
    printf 'android.jar: %s\n' "${android_jar}"
    printf 'build-tools: %s\n' "${build_tools_dir}"
fi

# Helper: run apksigner either via jar or binary
apksigner_run() {
    if [[ -n "${apksigner_jar:-}" && -f "${apksigner_jar}" ]]; then
        java -jar "${apksigner_jar}" "$@"
    else
        "${apksigner_cmd[@]}" "$@"
    fi
}

# --------------------------------------------------------------------------
# APK output path
# --------------------------------------------------------------------------
case "${signing_mode}" in
    debug)
        signed_apk="${build_dir}/byd-dashcam-debug.apk"
        ;;
    release)
        signed_apk="${build_dir}/byd-dashcam.apk"
        if [[ ! -f "${release_keystore}" ]]; then
            printf 'Missing release keystore: %s\n' "${release_keystore}" >&2
            exit 1
        fi
        if [[ ! -f "${release_password_file}" ]]; then
            printf 'Missing release password file: %s\n' "${release_password_file}" >&2
            exit 1
        fi
        ;;
    *)
        printf 'Unsupported BYD_CAMERA_SIGNING_MODE: %s (expected debug or release)\n' \
            "${signing_mode}" >&2
        exit 1
        ;;
esac

mkdir -p "${build_dir}" "${generated_dir}" "${stub_classes}" "${app_classes}"

if [[ ! -f "${vendor_jar}" ]]; then
    printf 'Missing vendor API jar: %s\n' "${vendor_jar}" >&2
    exit 1
fi

# --------------------------------------------------------------------------
# Phone UI build (optional if prebuilt assets exist)
# --------------------------------------------------------------------------
if [[ -d "${phone_ui_root}/node_modules" ]]; then
    npm --prefix "${phone_ui_root}" run build
elif [[ ! -f "${project_root}/assets/phone/index.html" ]]; then
    printf 'Missing compiled phone UI. Run: npm --prefix %s install && npm --prefix %s run build\n' \
        "${phone_ui_root}" "${phone_ui_root}" >&2
    exit 1
fi

# --------------------------------------------------------------------------
# aapt: package resources + generate R.java
# --------------------------------------------------------------------------
aapt package \
    -f \
    -m \
    -M "${project_root}/AndroidManifest.xml" \
    -S "${project_root}/res" \
    -A "${project_root}/assets" \
    -I "${android_jar}" \
    -J "${generated_dir}" \
    -F "${build_dir}/app-unsigned.apk"

# --------------------------------------------------------------------------
# javac: stub compile
# --------------------------------------------------------------------------
javac \
    -source 8 \
    -target 8 \
    -classpath "${android_jar}" \
    -d "${stub_classes}" \
    "${project_root}/stubs/android/hardware/AVMCamera.java"

# --------------------------------------------------------------------------
# javac: app sources
# --------------------------------------------------------------------------
find "${project_root}/src" "${generated_dir}" -name '*.java' | sort \
    > "${build_dir}/sources.txt"

javac \
    -source 8 \
    -target 8 \
    -classpath "${android_jar}:${stub_classes}" \
    -d "${app_classes}" \
    @"${build_dir}/sources.txt"

# --------------------------------------------------------------------------
# DEX: prefer dx (stable for older cars), else d8 with --min-api 23
# --------------------------------------------------------------------------
if [[ -n "${dx_jar:-}" && -f "${dx_jar}" ]]; then
    java -jar "${dx_jar}" \
        --dex \
        --output="${build_dir}/classes.dex" \
        "${app_classes}"
elif [[ -n "${d8_jar:-}" && -f "${d8_jar}" ]]; then
    find "${app_classes}" -name '*.class' | sort > "${build_dir}/classes.txt"
    java -cp "${d8_jar}" com.android.tools.r8.D8 \
        --min-api 23 \
        --output "${build_dir}" \
        --lib "${android_jar}" \
        @"${build_dir}/classes.txt"
else
    printf 'No DEX tool found (dx.jar or d8.jar).\n' >&2
    exit 1
fi

if [[ ! -f "${build_dir}/classes.dex" ]]; then
    printf 'classes.dex was not produced.\n' >&2
    exit 1
fi

# --------------------------------------------------------------------------
# Add vendor DEX + app DEX into APK (store uncompressed for reliable parse)
# --------------------------------------------------------------------------
unzip -p "${vendor_jar}" classes.dex > "${build_dir}/classes2.dex"

# Remove any existing classes*.dex that aapt may have left, then add STORED
(
    cd "${build_dir}"
    # strip old dex entries if present (ignore errors)
    zip -d app-unsigned.apk 'classes*.dex' 2>/dev/null || true
    # -0 = store (no compression) — safer for PackageManager on some DiLink units
    zip -0 -j app-unsigned.apk classes.dex classes2.dex
)

# --------------------------------------------------------------------------
# zipalign (must run before signing)
# --------------------------------------------------------------------------
zipalign \
    -f \
    4 \
    "${build_dir}/app-unsigned.apk" \
    "${build_dir}/app-aligned.apk"

# --------------------------------------------------------------------------
# Sign: force v1 + v2 (disable v3) for maximum DiLink compatibility
# --------------------------------------------------------------------------
if [[ "${signing_mode}" == "debug" ]]; then
    if [[ ! -f "${build_dir}/debug.keystore" ]]; then
        keytool \
            -genkeypair \
            -keystore "${build_dir}/debug.keystore" \
            -storepass android \
            -alias androiddebugkey \
            -keypass android \
            -dname "CN=Android Debug,O=Android,C=US" \
            -keyalg RSA \
            -keysize 2048 \
            -validity 10000
    fi

    apksigner_run sign \
        --ks "${build_dir}/debug.keystore" \
        --ks-pass pass:android \
        --key-pass pass:android \
        --v1-signing-enabled true \
        --v2-signing-enabled true \
        --v3-signing-enabled false \
        --out "${signed_apk}" \
        "${build_dir}/app-aligned.apk"
else
    apksigner_run sign \
        --ks "${release_keystore}" \
        --ks-key-alias "${release_key_alias}" \
        --ks-pass "file:${release_password_file}" \
        --v1-signing-enabled true \
        --v2-signing-enabled true \
        --v3-signing-enabled false \
        --debuggable-apk-permitted false \
        --out "${signed_apk}" \
        "${build_dir}/app-aligned.apk"
fi

apksigner_run verify \
    --verbose \
    --print-certs \
    "${signed_apk}"

printf 'Built %s APK: %s\n' "${signing_mode}" "${signed_apk}"
printf 'Tip: install on car with: adb install -r %s\n' "${signed_apk}"
