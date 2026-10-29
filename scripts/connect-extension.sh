#!/usr/bin/env bash
# ==============================================================================
# Edit.or.lynx - 1-Click Browser Extension Connector
# Automatically installs and injects the Edit.or.lynx extension into any browser.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BROWSER="${1:-all}"
BROWSER_LOWER="$(echo "$BROWSER" | tr '[:upper:]' '[:lower:]')"

APP_SUPPORT="$HOME/Library/Application Support/Edit.or.lynx"
EXT_DEST="$APP_SUPPORT/Extension"
CHROME_SRC=""
FIREFOX_SRC=""

# 1. Resolve source extension paths
if [ -d "$ROOT_DIR/Extension/chrome" ]; then
    CHROME_SRC="$ROOT_DIR/Extension/chrome"
    FIREFOX_SRC="$ROOT_DIR/Extension/firefox"
elif [ -d "/Applications/Edit.or.lynx.app/Contents/Resources/Extension/chrome" ]; then
    CHROME_SRC="/Applications/Edit.or.lynx.app/Contents/Resources/Extension/chrome"
    FIREFOX_SRC="/Applications/Edit.or.lynx.app/Contents/Resources/Extension/firefox"
elif [ -d "$EXT_DEST/chrome" ]; then
    CHROME_SRC="$EXT_DEST/chrome"
    FIREFOX_SRC="$EXT_DEST/firefox"
fi

# 2. Deploy extension to stable Application Support folder
mkdir -p "$EXT_DEST/chrome" "$EXT_DEST/firefox"
if [ -n "$CHROME_SRC" ] && [ "$CHROME_SRC" != "$EXT_DEST/chrome" ]; then
    cp -R "$CHROME_SRC/"* "$EXT_DEST/chrome/" 2>/dev/null || true
fi
if [ -n "$FIREFOX_SRC" ] && [ "$FIREFOX_SRC" != "$EXT_DEST/firefox" ]; then
    cp -R "$FIREFOX_SRC/"* "$EXT_DEST/firefox/" 2>/dev/null || true
fi

STABLE_CHROME="$EXT_DEST/chrome"
STABLE_FIREFOX="$EXT_DEST/firefox"

echo "▸ Edit.or.lynx 1-Click Browser Connector: target '$BROWSER_LOWER'"

# Helper to install for Chromium-based browsers
install_chromium() {
    local name="$1"
    local app_name="$2"
    local support_dir="$3"
    local ext_url="$4"

    echo "  → Connecting to $name..."
    local ext_reg="$support_dir/External Extensions"
    mkdir -p "$ext_reg"

    # Write external extensions manifest (Chromium standard discovery)
    cat <<EOF > "$ext_reg/jbmhnhbignkonakengimnnemmlecmbpd.json"
{
  "external_path": "$STABLE_CHROME",
  "external_version": "1.0.0"
}
EOF
    cp "$ext_reg/jbmhnhbignkonakengimnnemmlecmbpd.json" "$ext_reg/editorlynx.json" 2>/dev/null || true

    # Also install into Default Profile extensions folder
    local default_ext="$support_dir/Default/Extensions/editorlynx"
    mkdir -p "$default_ext"
    cp -R "$STABLE_CHROME/"* "$default_ext/" 2>/dev/null || true

    # Launch browser with extension loaded directly
    if [ -d "/Applications/$app_name.app" ] || [ -d "$HOME/Applications/$app_name.app" ]; then
        open -a "$app_name" --args --load-extension="$STABLE_CHROME" 2>/dev/null || open -a "$app_name" "$ext_url" 2>/dev/null || true
        # Bring browser window to front and open extensions page
        osascript -e "tell application \"$app_name\" to activate" 2>/dev/null || true
        echo "  ✓ $name: Extension registered and browser opened."
    else
        echo "  ✓ $name: Extension registered in Application Support (App not currently installed at /Applications/$app_name.app)."
    fi
}

# Helper to install for Firefox-based browsers
install_firefox_family() {
    local name="$1"
    local app_name="$2"
    local profiles_dir="$3"
    local profiles_dir_alt="${4:-}"

    echo "  → Connecting to $name..."
    local xpi_tmp="$EXT_DEST/edit-or-lynk@local.xpi"
    (cd "$STABLE_FIREFOX" && zip -q -r "$xpi_tmp" *) 2>/dev/null || true

    for base in "$profiles_dir" "$profiles_dir_alt"; do
        if [ -n "$base" ] && [ -d "$base" ]; then
            for profile in "$base"/*; do
                if [ -d "$profile" ]; then
                    local ext_dir="$profile/extensions"
                    mkdir -p "$ext_dir"
                    # 1. Install as XPI
                    cp "$xpi_tmp" "$ext_dir/edit-or-lynk@local.xpi" 2>/dev/null || true
                    # 2. Also install as unpacked gecko-id directory
                    local target="$ext_dir/edit-or-lynk@local"
                    rm -rf "$target"
                    mkdir -p "$target"
                    cp -R "$STABLE_FIREFOX/"* "$target/" 2>/dev/null || true

                    # 3. Configure user.js to allow local extension
                    mkdir -p "$profile"
                    grep -q "xpinstall.signatures.required" "$profile/user.js" 2>/dev/null || {
                        echo 'user_pref("xpinstall.signatures.required", false);' >> "$profile/user.js"
                        echo 'user_pref("extensions.autoDisableScopes", 0);' >> "$profile/user.js"
                        echo 'user_pref("extensions.enabledScopes", 15);' >> "$profile/user.js"
                    }
                fi
            done
            echo "  ✓ $name: Extension installed into active profile(s) in $base."
        fi
    done

    # Write distribution policies for automatic silent install
    local policy_json='{"policies":{"ExtensionSettings":{"edit-or-lynk@local":{"installation_mode":"normal_installed","install_url":"file://'"$xpi_tmp"'"}}}}'
    mkdir -p "/Applications/$app_name.app/Contents/Resources/distribution" 2>/dev/null || true
    echo "$policy_json" > "/Applications/$app_name.app/Contents/Resources/distribution/policies.json" 2>/dev/null || true
    mkdir -p "/Applications/$app_name Browser.app/Contents/Resources/distribution" 2>/dev/null || true
    echo "$policy_json" > "/Applications/$app_name Browser.app/Contents/Resources/distribution/policies.json" 2>/dev/null || true
    mkdir -p "$HOME/Library/Application Support/Firefox/distribution" 2>/dev/null || true
    echo "$policy_json" > "$HOME/Library/Application Support/Firefox/distribution/policies.json" 2>/dev/null || true
    mkdir -p "$HOME/Library/Application Support/zen/distribution" 2>/dev/null || true
    echo "$policy_json" > "$HOME/Library/Application Support/zen/distribution/policies.json" 2>/dev/null || true

    local real_app=""
    if [ -d "/Applications/$app_name.app" ]; then
        real_app="/Applications/$app_name.app"
    elif [ -d "/Applications/$app_name Browser.app" ]; then
        real_app="/Applications/$app_name Browser.app"
    elif [ -d "$HOME/Applications/$app_name.app" ]; then
        real_app="$HOME/Applications/$app_name.app"
    fi

    if [ -n "$real_app" ]; then
        # Open the XPI directly to trigger the 1-click install confirmation in Zen/Firefox
        if [ -f "$xpi_tmp" ]; then
            open -a "$real_app" "$xpi_tmp" 2>/dev/null || open "$xpi_tmp" 2>/dev/null || true
        fi
        osascript -e "tell application \"$real_app\" to activate" 2>/dev/null || true
        echo "  ✓ $name: Browser activated with 1-click add-on prompt."
    fi
}

# Process target browser
case "$BROWSER_LOWER" in
    chrome|"google chrome")
        install_chromium "Google Chrome" "Google Chrome" "$HOME/Library/Application Support/Google/Chrome" "chrome://extensions"
        ;;
    brave|"brave browser")
        install_chromium "Brave Browser" "Brave Browser" "$HOME/Library/Application Support/BraveSoftware/Brave-Browser" "brave://extensions"
        ;;
    edge|"microsoft edge")
        install_chromium "Microsoft Edge" "Microsoft Edge" "$HOME/Library/Application Support/Microsoft Edge" "edge://extensions"
        ;;
    arc|"arc browser")
        install_chromium "Arc" "Arc" "$HOME/Library/Application Support/Arc/User Data" "arc://extensions"
        ;;
    dia|"dia browser")
        if [ -d "/Applications/Dia Browser.app" ]; then
            install_chromium "Dia Browser" "Dia Browser" "$HOME/Library/Application Support/Dia/User Data" "chrome://extensions"
        else
            install_chromium "Dia" "Dia" "$HOME/Library/Application Support/Dia/User Data" "chrome://extensions"
        fi
        ;;
    firefox|"mozilla firefox")
        install_firefox_family "Mozilla Firefox" "Firefox" "$HOME/Library/Application Support/Firefox/Profiles"
        ;;
    zen|"zen browser")
        install_firefox_family "Zen Browser" "Zen" "$HOME/Library/Application Support/zen/Profiles" "$HOME/Library/Application Support/Zen/Profiles"
        ;;
    safari|"apple safari")
        echo "  → Safari Web Extension requires system enabling."
        open -a "Safari" "https://support.apple.com/guide/safari/use-safari-extensions-sfri32508/mac" 2>/dev/null || true
        ;;
    all)
        install_chromium "Google Chrome" "Google Chrome" "$HOME/Library/Application Support/Google/Chrome" "chrome://extensions"
        install_chromium "Brave Browser" "Brave Browser" "$HOME/Library/Application Support/BraveSoftware/Brave-Browser" "brave://extensions"
        install_chromium "Microsoft Edge" "Microsoft Edge" "$HOME/Library/Application Support/Microsoft Edge" "edge://extensions"
        install_chromium "Arc" "Arc" "$HOME/Library/Application Support/Arc/User Data" "arc://extensions"
        install_chromium "Dia" "Dia" "$HOME/Library/Application Support/Dia/User Data" "chrome://extensions"
        install_firefox_family "Mozilla Firefox" "Firefox" "$HOME/Library/Application Support/Firefox/Profiles"
        install_firefox_family "Zen Browser" "Zen" "$HOME/Library/Application Support/zen/Profiles" "$HOME/Library/Application Support/Zen/Profiles"
        ;;
    *)
        echo "Unknown browser: $BROWSER. Supported: chrome, brave, edge, arc, dia, firefox, zen, safari, all"
        exit 1
        ;;
esac

echo "▸ 1-Click Extension Connect complete."
