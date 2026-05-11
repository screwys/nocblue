export QS_ICON_THEME="${QS_ICON_THEME:-candy-icons}"
export QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-qt6ct}"
export QT_WAYLAND_DISABLE_WINDOWDECORATION="${QT_WAYLAND_DISABLE_WINDOWDECORATION:-1}"
export ELECTRON_OZONE_PLATFORM_HINT="${ELECTRON_OZONE_PLATFORM_HINT:-auto}"
export PYTHON_KEYRING_BACKEND="${PYTHON_KEYRING_BACKEND:-keyring.backends.SecretService.Keyring}"
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-nvim}"
export TERMINAL="${TERMINAL:-/usr/bin/ghostty}"

for nocblue_java_home in /usr/lib/jvm/java-latest-openjdk /usr/lib/jvm/java; do
    if [ -x "${nocblue_java_home}/bin/java" ]; then
        export JAVA_HOME="${JAVA_HOME:-${nocblue_java_home}}"
        case ":${PATH}:" in
            *":${JAVA_HOME}/bin:"*) ;;
            *) export PATH="${JAVA_HOME}/bin:${PATH}" ;;
        esac
        break
    fi
done
unset nocblue_java_home

export ANDROID_HOME="${ANDROID_HOME:-${HOME}/Android/Sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME}}"
for nocblue_android_path in "${ANDROID_HOME}/cmdline-tools/latest/bin" "${ANDROID_HOME}/platform-tools"; do
    if [ -d "${nocblue_android_path}" ]; then
        case ":${PATH}:" in
            *":${nocblue_android_path}:"*) ;;
            *) export PATH="${nocblue_android_path}:${PATH}" ;;
        esac
    fi
done
unset nocblue_android_path

for nocblue_brew_prefix in /home/linuxbrew/.linuxbrew /var/home/linuxbrew/.linuxbrew; do
    if [ -d "${nocblue_brew_prefix}" ]; then
        case ":${PATH}:" in
            *":${nocblue_brew_prefix}/bin:"*) ;;
            *) export PATH="${nocblue_brew_prefix}/bin:${PATH}" ;;
        esac
        break
    fi
done
unset nocblue_brew_prefix
