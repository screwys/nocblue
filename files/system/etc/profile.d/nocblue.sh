export QS_ICON_THEME="${QS_ICON_THEME:-Candy}"
export QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-qt6ct}"
export QT_WAYLAND_DISABLE_WINDOWDECORATION="${QT_WAYLAND_DISABLE_WINDOWDECORATION:-1}"
export ELECTRON_OZONE_PLATFORM_HINT="${ELECTRON_OZONE_PLATFORM_HINT:-auto}"
export PYTHON_KEYRING_BACKEND="${PYTHON_KEYRING_BACKEND:-keyring.backends.SecretService.Keyring}"

for nocblue_brew_prefix in /home/linuxbrew/.linuxbrew /var/home/linuxbrew/.linuxbrew; do
    if [ -d "${nocblue_brew_prefix}" ]; then
        case ":${PATH}:" in
            *":${nocblue_brew_prefix}/bin:"*) ;;
            *) export PATH="${nocblue_brew_prefix}/bin:${PATH}" ;;
        esac

        if [ -d "${nocblue_brew_prefix}/opt/openjdk@17" ]; then
            export JAVA_HOME="${JAVA_HOME:-${nocblue_brew_prefix}/opt/openjdk@17}"
            case ":${PATH}:" in
                *":${JAVA_HOME}/bin:"*) ;;
                *) export PATH="${JAVA_HOME}/bin:${PATH}" ;;
            esac
        fi
        break
    fi
done
unset nocblue_brew_prefix
