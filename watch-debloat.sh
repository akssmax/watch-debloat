#!/usr/bin/env bash
# ============================================================================
#  watch-debloat.sh — Galaxy Watch 4 (Wear OS) debloat toolkit
#
#  Interactive, reversible debloat for Samsung Galaxy Watch 4 / 5 / 6 / 7.
#  No root. No PC app. Just ADB over Wi-Fi.
#
#  Quick start:
#      ./watch-debloat.sh
#
#  Other modes:
#      ./watch-debloat.sh --quick                 # safest preset
#      ./watch-debloat.sh --medium                # balanced preset
#      ./watch-debloat.sh --advanced              # pick each group yourself
#      ./watch-debloat.sh --list                  # show every group
#      ./watch-debloat.sh --dry-run               # preview only
#      ./watch-debloat.sh --restore debloat-X.log # undo a run
#      ./watch-debloat.sh --device 192.168.1.20:5555
#
#  Tested on: SM-R870 (Galaxy Watch 4 44mm), Wear OS, Android 16
#  License: MIT
# ============================================================================

VERSION="1.0.0"

# ---------------------------------------------------------------- ui helpers

c_reset=$'\033[0m'; c_bold=$'\033[1m'; c_dim=$'\033[2m'
c_red=$'\033[31m'; c_grn=$'\033[32m'; c_yel=$'\033[33m'
c_blu=$'\033[36m'; c_inv=$'\033[7m'

say()  { printf '%s\n' "$*"; }
ok()   { printf '  %s✓%s %s\n' "$c_grn" "$c_reset" "$*"; }
warn() { printf '  %s!%s %s\n' "$c_yel" "$c_reset" "$*"; }
err()  { printf '  %s✗%s %s\n' "$c_red" "$c_reset" "$*" >&2; }
die()  { err "$*"; exit 1; }
hr()   { printf '%s\n' "────────────────────────────────────────────────────────────"; }

banner() {
  printf '\n%s%s  Galaxy Watch Debloat%s  %sv%s\n' \
    "$c_bold" "$c_blu" "$c_reset" "$c_dim" "$VERSION"
  printf '%s  %s%s\n\n' "$c_dim" "Reversible · no root · wireless ADB" "$c_reset"
}

# ---------------------------------------------------------------- adb helpers

ensure_adb() {
  if command -v adb >/dev/null 2>&1; then return 0; fi
  err "adb not found."
  say ""
  say "  Install it with one of these:"
  say "    macOS     brew install --cask android-platform-tools"
  say "    Debian    sudo apt install android-tools-adb"
  say "    Fedora    sudo dnf install android-tools"
  say "    Windows   https://developer.android.com/tools/releases/platform-tools"
  say ""
  exit 1
}

adb_() { adb -s "$DEVICE" "$@" < /dev/null 2>/dev/null; }

# adb inherits stdin and will happily swallow the keystrokes meant for the
# interactive menus. Every adb invocation therefore gets </dev/null.
adb_plain() { adb "$@" < /dev/null 2>/dev/null; }

device_ready() {
  [ -n "${DEVICE:-}" ] || return 1
  [ "$(adb_ get-state 2>/dev/null)" = "device" ]
}

# ---------------------------------------------------------------- package data
#
# Parallel arrays (bash 3.2 compatible - no associative arrays).
# Group i has title GROUP_TITLE[i], hint GROUP_HINT[i], packages GROUP_PKGS[i].

GROUP_KEY=(
  bixby telemetry factory demo faces goals fonts google
  lte knox bundled playstore samsung_apps find sync media_sessions a11y
)

GROUP_TITLE=(
  "Bixby voice assistant"
  "Samsung telemetry & diagnostics"
  "Factory / service-mode tools"
  "Demo, CTS & provisioning residue"
  "Alternate watchfaces"
  "Global Goals face packs"
  "Bundled fonts"
  "Google extras"
  "LTE / IMS stack"
  "Knox enterprise (MDM)"
  "Bundled third-party apps"
  "Play Store (disable only)"
  "Samsung apps"
  "Samsung Find"
  "Samsung background sync"
  "Media session listener"
  "Accessibility & TTS engines"
)

GROUP_HINT=(
  "Always-listening wake word. Big battery win."
  "Telemetry agents that report to Samsung."
  "Hardware test menus. No user value."
  "Store demo loop, CTS stubs, partner setup."
  "29 extra faces. Keep at least one analogue + digital."
  "Donation face packs (com.samsung.sree.*)."
  "ChocoCooky, CoolJazz, Rosemary."
  "Assistant, Chromecast, GoogleCamera, SoundCloud."
  "Dead code on Wi-Fi-only watches (SM-R860/R870)."
  "Enterprise device management."
  "Outlook, Smart Switch, Smart Switch assistant."
  "Re-enable anytime with: pm enable --user 0 com.android.vending"
  "Pay, Music, Buds, SmartThings, Galaxy Store, Weather, Calculator, Voice Recorder."
  "Find My Phone app."
  "MCFDeviceSync + MdecService."
  "Detects media playing on your phone (1-5% battery)."
  "TalkBack, Samsung TTS, Google TTS."
)

GROUP_PKGS=(
  "com.samsung.android.bixby.agent com.samsung.android.bixby.wakeup com.samsung.android.intellivoiceservice"
  "com.samsung.android.dqagent com.sec.android.diagmonagent com.sec.android.sdhms com.samsung.android.watch.selfdiagnostics com.sec.facatfunction"
  "com.sec.android.app.hwmoduletest com.sec.android.app.servicemodeapp com.sec.android.app.wlantest com.sec.android.app.factorykeystring com.sec.android.app.parser com.sec.bcservice com.sec.usbsettings com.samsung.android.providers.factory"
  "com.google.android.apps.wearable.retailattractloop com.android.cts.ctsshim com.android.cts.priv.ctsshim com.google.android.partnersetup com.android.managedprovisioning com.android.adservices.api com.samsung.android.wearable.setupwizard"
  "com.samsung.android.watch.watchface.animal com.samsung.android.watch.watchface.endangeredanimal com.samsung.android.watch.watchface.aremoji com.samsung.android.watch.watchface.bitmoji com.samsung.android.watch.watchface.myphoto com.samsung.android.watch.watchface.mystyle com.samsung.android.watch.watchface.together com.samsung.android.watch.watchface.typography com.samsung.android.watch.watchface.large com.samsung.android.watch.watchface.dualwatch com.samsung.android.watch.watchface.analoguefont com.samsung.android.watch.watchface.digitalfont com.samsung.android.watch.watchface.digitalmodular com.samsung.android.watch.watchface.basicdashboard com.samsung.android.watch.watchface.bespoke com.samsung.android.watch.watchface.premiumanalog com.samsung.android.watch.watchface.superfiction com.samsung.android.watch.watchface.livewallpaper com.samsung.android.watch.watchface.simplecomplication com.samsung.android.watch.watchface.healthmodular com.samsung.android.watch.watchface.simpleclassic com.samsung.android.watch.watchface.simpleanalogue com.samsung.android.watch.watchface.weather com.samsung.android.watch.watchface.emergency com.samsung.android.watch.watchface.spatialnumber com.samsung.android.watch.watchface.boldindex com.samsung.android.watch.watchface.gradientinfoboard com.samsung.android.watch.watchface.sportyclassic com.samsung.android.watch.watchface.tomcat com.samsung.android.watch.watchface.tickingsound"
  "com.samsung.sree com.samsung.sree.classic com.samsung.sree.countdown com.samsung.sree.digital com.samsung.sree.spin"
  "com.monotype.android.font.chococooky com.monotype.android.font.cooljazz com.monotype.android.font.rosemary"
  "com.google.android.wearable.assistant com.google.android.apps.chromecast.app com.google.android.GoogleCamera com.soundcloud.android"
  "com.sec.imsservice com.samsung.advp.imssettings com.android.cellbroadcastreceiver"
  "com.sds.emm.cloud.knox.samsung com.skms.android.agent"
  "com.microsoft.office.outlook com.sec.android.easyMover com.samsung.android.wear.smartswitchassistant"
  "com.android.vending"
  "com.samsung.android.samsungpay.gear com.samsung.android.wearable.music com.samsung.android.watch.budscontroller com.samsung.android.oneconnect com.sec.android.app.samsungapps com.samsung.android.watch.weather com.samsung.android.wear.voicerecorder com.samsung.android.wear.calculator com.samsung.android.wear.musictransfer"
  "com.samsung.android.app.find"
  "com.samsung.android.mcfds com.samsung.android.mdecservice"
  "com.samsung.android.wearable.media.sessions"
  "com.google.android.marvin.talkback com.samsung.SMT com.google.android.tts"
)

# Presets --------------------------------------------------------------------

PRESET_QUICK="bixby telemetry factory demo"
PRESET_MEDIUM="bixby telemetry factory demo faces goals fonts google lte knox bundled playstore"

# Packages that must never be uninstalled - disabled instead.
DISABLE_ONLY="com.android.vending"

# Never remove these, whatever the user selects.
PROTECTED="com.samsung.android.honeyboard"
PROTECTED_NOTE="keyboard (only IME on most watches)"

# ---------------------------------------------------------------- utilities

group_index() {
  local key="$1" i=0
  while [ $i -lt ${#GROUP_KEY[@]} ]; do
    if [ "${GROUP_KEY[$i]}" = "$key" ]; then echo $i; return 0; fi
    i=$((i + 1))
  done
  return 1
}

is_in_list() {  # is_in_list <needle> <space separated haystack>
  local n="$1" h=" $2 "
  case "$h" in *" $n "*) return 0 ;; esac
  return 1
}

pkgs_for_indexes() {  # echo unique package list for selected group indexes
  local -a out=()
  local idx pkg seen
  for idx in "$@"; do
    for pkg in ${GROUP_PKGS[$idx]}; do
      seen=0
      local q
      for q in "${out[@]:-}"; do [ "$q" = "$pkg" ] && seen=1 && break; done
      [ $seen -eq 0 ] && out+=("$pkg")
    done
  done
  printf '%s\n' "${out[@]:-}"
}

active_watchface() {
  adb_ shell dumpsys wallpaper 2>/dev/null \
    | grep -o 'com\.samsung\.android\.watch\.watchface\.[a-z0-9_]*' \
    | head -1
}

# ---------------------------------------------------------------- tui

KEY_TIMEOUT="1"
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] && KEY_TIMEOUT="0.05"

read_key() {
  # NOTE: must NOT be called as `key=$(read_key)`.
  # A command substitution runs in a subshell, and bash discards the bytes it
  # had buffered from the pipe when that subshell exits - which silently drops
  # every keystroke after the first. We therefore read into a global.
  KEY=""
  local k2
  IFS= read -rsn1 KEY
  if [ "$KEY" = $'\033' ]; then
    IFS= read -rsn2 -t "$KEY_TIMEOUT" k2
    KEY="$KEY${k2:-}"
  fi
}

tui_multiselect() {  # sets global SELECTED (space separated indexes)
  local -a sel=()
  local cur=0 n="${#GROUP_KEY[@]}" i key total

  for ((i = 0; i < n; i++)); do sel+=("0"); done

  while true; do
    printf '\033[2J\033[H'
    printf '%s%s  Select what to remove%s\n' "$c_bold" "$c_blu" "$c_reset"
    printf '%s  ↑/↓ move · SPACE toggle · A all · N none · ENTER confirm · Q quit%s\n\n' "$c_dim" "$c_reset"

    total=0
    for ((i = 0; i < n; i++)); do
      local mark="[ ]" colour="$c_reset"
      [ "${sel[$i]}" = "1" ] && mark="[x]" && colour="$c_grn"
      local pkgnum
      pkgnum=$(printf '%s' "${GROUP_PKGS[$i]}" | wc -w | tr -d ' ')
      total=$((total + ${sel[$i]} * pkgnum))

      if [ $i -eq $cur ]; then
        printf ' %s%s %s %-30s%s %2s pkg%s\n' \
          "$c_inv" "$mark" "$c_reset" "${GROUP_TITLE[$i]}" "$c_dim" "$pkgnum" "$c_reset"
        printf '      %s%s%s\n' "$c_dim" "${GROUP_HINT[$i]}" "$c_reset"
      else
        printf '  %s%s%s %-30s%s %2s pkg%s\n' \
          "$colour" "$mark" "$c_reset" "${GROUP_TITLE[$i]}" "$c_dim" "$pkgnum" "$c_reset"
      fi
    done

    printf '\n  %s%d package(s) selected%s\n' "$c_bold" "$total" "$c_reset"

    key=""
    read_key
    key="$KEY"
    case "$key" in
      $'\033[A') cur=$((cur - 1)); [ $cur -lt 0 ] && cur=$((n - 1)) ;;
      $'\033[B') cur=$((cur + 1)); [ $cur -ge $n ] && cur=0 ;;
      ' ')      if [ "${sel[$cur]}" = "1" ]; then sel[$cur]="0"; else sel[$cur]="1"; fi ;;
      a|A)      for ((i = 0; i < n; i++)); do sel[$i]="1"; done ;;
      n|N)      for ((i = 0; i < n; i++)); do sel[$i]="0"; done ;;
      q|Q)      printf '\033[2J\033[H'; return 1 ;;
      '')       break ;;   # ENTER
    esac
  done

  SELECTED=""
  for ((i = 0; i < n; i++)); do
    [ "${sel[$i]}" = "1" ] && SELECTED="$SELECTED $i"
  done
  SELECTED="${SELECTED# }"
  printf '\033[2J\033[H'
  return 0
}

confirm() {  # confirm "question"
  local ans
  printf '%s?%s %s [y/N] ' "$c_yel" "$c_reset" "$1"
  IFS= read -r ans
  case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------- connect

CONNECT_GUIDE() {
  say "${c_bold}On the watch:${c_reset}"
  say "  1. Settings → About watch → Software information"
  say "     Tap ${c_bold}Software version${c_reset} 5×  →  \"Developer mode enabled\""
  say "  2. Settings → Developer options"
  say "     Turn ON  ${c_bold}ADB debugging${c_reset}"
  say "     Turn ON  ${c_bold}Wireless debugging${c_reset}"
  say "  3. Stay on the Wireless debugging screen."
  say "     It shows  ${c_bold}IP address & port${c_reset}  e.g. 192.168.1.20:35473"
  say ""
  say "${c_bold}Keep the watch on its charger and the screen awake${c_reset} while pairing."
  say "The pairing dialog expires in about 60 seconds."
  say ""
}

connect_wizard() {
  banner
  CONNECT_GUIDE

  say "Do you see a ${c_bold}\"Pair new device\"${c_reset} option on that screen?"
  say "  ${c_dim}(You need it the first time. After pairing once, skip it.)${c_reset}"
  say ""
  if confirm "Pair now?"; then
    say ""
    printf '  Pairing port shown on the pair screen (e.g. 39373): '
    IFS= read -r pairport
    printf '  6-digit pairing code (e.g. 077995): '
    IFS= read -r paircode
    printf '  Watch IP (e.g. 192.168.1.20): '
    IFS= read -r ip

    [ -n "$ip" ] && [ -n "$pairport" ] && [ -n "$paircode" ] || die "Missing input."
    say ""
    say "  Pairing…"
    printf '%s\n' "$paircode" | adb pair "${ip}:${pairport}" < /dev/null 2>&1 | sed 's/^/    /'
    say ""
    say "  ${c_dim}If you saw 'Successfully paired', you're good.${c_reset}"
  else
    printf '  Watch IP: '
    IFS= read -r ip
  fi

  say ""
  say "Now enter the ${c_bold}connect${c_reset} port."
  say "  ${c_dim}That's the port on the main Wireless debugging screen${c_reset}"
  say "  ${c_dim}(it is DIFFERENT from the pairing port).${c_reset}"
  printf '  Connect port: '
  IFS= read -r cport

  DEVICE="${ip}:${cport}"
  say ""
  say "  Connecting to ${c_bold}${DEVICE}${c_reset}…"
  adb connect "$DEVICE" < /dev/null 2>&1 | sed 's/^/    /'
  sleep 1

  if device_ready; then
    ok "Connected."
    adb_ shell getprop ro.product.model 2>/dev/null | sed 's/^/    model: /'
  else
    err "Could not connect."
    say ""
    say "  Common causes:"
    say "    · watch Wi-Fi asleep  → wake the screen, keep it on the charger"
    say "    · wrong port          → re-read it on the Wireless debugging screen"
    say "    · not paired          → run the pairing step again"
    say "    · different network   → watch and computer must be on the same Wi-Fi"
    exit 1
  fi
}

pick_device() {
  local list count
  list=$(adb devices < /dev/null | awk 'NR>1 && $2=="device"{print $1}')
  count=$(printf '%s\n' "$list" | grep -c . )
  if [ "$count" -eq 1 ]; then DEVICE="$list"; return 0; fi
  if [ "$count" -eq 0 ]; then
    connect_wizard
    return 0
  fi
  say "Multiple devices:"
  printf '%s\n' "$list" | nl -ba
  printf '  Pick one: '
  local n; IFS= read -r n
  DEVICE=$(printf '%s\n' "$list" | sed -n "${n}p")
  [ -n "$DEVICE" ] || die "Invalid selection."
}

# ---------------------------------------------------------------- apply

apply_list() {
  local pkgs="$1" pkg out removed=0 kept=0 failed=0
  local face; face=$(active_watchface)
  local log="debloat-$(date +%Y%m%d-%H%M%S).log"
  : > "$log"

  [ -n "$face" ] && say "  ${c_dim}Active watchface protected: ${face}${c_reset}" && say ""

  for pkg in $pkgs; do
    if [ "$pkg" = "$PROTECTED" ]; then
      printf '  %sKEEP%s    %s  (%s)\n' "$c_yel" "$c_reset" "$pkg" "$PROTECTED_NOTE"; kept=$((kept+1)); continue
    fi
    if [ -n "$face" ] && [ "$pkg" = "$face" ]; then
      printf '  %sKEEP%s    %s  (active watchface)\n' "$c_yel" "$c_reset" "$pkg"; kept=$((kept+1)); continue
    fi
    if ! adb_ shell pm list packages --user 0 "$pkg" 2>/dev/null | grep -q "package:$pkg"; then
      printf '  %sskip%s    %s  (not installed)\n' "$c_dim" "$c_reset" "$pkg"; continue
    fi

    if [ "$DRY_RUN" = 1 ]; then
      printf '  %sdry%s     %s\n' "$c_blu" "$c_reset" "$pkg"; removed=$((removed+1)); continue
    fi

    if is_in_list "$pkg" "$DISABLE_ONLY"; then
      out=$(adb_ shell pm disable-user --user 0 "$pkg" 2>&1)
      if printf '%s' "$out" | grep -qi disabled; then
        printf '  %sDISABLE%s %s\n' "$c_yel" "$c_reset" "$pkg"
        echo "DISABLE $pkg" >> "$log"; removed=$((removed+1))
      else
        printf '  %sFAIL%s    %s\n' "$c_red" "$c_reset" "$pkg"; failed=$((failed+1))
      fi
      continue
    fi

    out=$(adb_ shell pm uninstall --user 0 "$pkg" 2>&1)
    if printf '%s' "$out" | grep -qi success; then
      printf '  %sREMOVED%s %s\n' "$c_grn" "$c_reset" "$pkg"
      echo "UNINSTALL $pkg" >> "$log"; removed=$((removed+1))
    else
      out=$(adb_ shell pm disable-user --user 0 "$pkg" 2>&1)
      if printf '%s' "$out" | grep -qi disabled; then
        printf '  %sDISABLE%s %s %s(fallback)%s\n' "$c_yel" "$c_reset" "$pkg" "$c_dim" "$c_reset"
        echo "DISABLE $pkg" >> "$log"; removed=$((removed+1))
      else
        printf '  %sFAIL%s    %s %s\n' "$c_red" "$c_reset" "$pkg" "$(printf '%s' "$out" | tr '\n' ' ')"
        failed=$((failed+1))
      fi
    fi
  done

  say ""
  hr
  say "  processed=${removed}  kept=${kept}  failed=${failed}"
  if [ "$DRY_RUN" = 1 ]; then
    say "  ${c_dim}Dry run - nothing was changed.${c_reset}"
  else
    say "  Log: ${c_bold}${log}${c_reset}"
    say "  Undo: ${c_bold}./watch-debloat.sh --restore ${log}${c_reset}"
  fi
}

tune() {
  say ""
  say "  ${c_bold}Performance tuning${c_reset}"
  if [ "$DRY_RUN" = 1 ]; then say "  ${c_dim}dry run - skipped${c_reset}"; return; fi
  adb_ shell settings put global window_animation_scale 0.5      >/dev/null 2>&1 && ok "animation scales → 0.5"
  adb_ shell settings put global transition_animation_scale 0.5  >/dev/null 2>&1
  adb_ shell settings put global animator_duration_scale 0.5     >/dev/null 2>&1
  say "  ${c_dim}running bg-dexopt-job (takes a few minutes)…${c_reset}"
  adb_ shell cmd package bg-dexopt-job >/dev/null 2>&1 && ok "dexopt complete"
  adb_ shell pm trim-caches 128G >/dev/null 2>&1 && ok "caches trimmed"
}

# ---------------------------------------------------------------- restore

do_restore() {
  local log="$1" kind pkg
  [ -f "$log" ] || die "No such log: $log"
  say "  Restoring from ${c_bold}${log}${c_reset}"
  say ""
  while read -r kind pkg; do
    case "$kind" in
      UNINSTALL)
        if adb_ shell cmd package install-existing --user 0 "$pkg" >/dev/null 2>&1; then
          ok "restored $pkg"
        else
          err "failed   $pkg"
        fi ;;
      DISABLE)
        if adb_ shell pm enable --user 0 "$pkg" >/dev/null 2>&1; then
          ok "enabled  $pkg"
        else
          err "failed   $pkg"
        fi ;;
    esac
  done < "$log"
}

# ---------------------------------------------------------------- main

DRY_RUN=0
MODE=""
DEVICE="${WATCH_DEVICE:-}"
RESTORE_LOG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --quick)    MODE="quick" ;;
    --medium)   MODE="medium" ;;
    --advanced) MODE="advanced" ;;
    --tune)     WANT_TUNE=1 ;;
    --dry-run|-n) DRY_RUN=1 ;;
    --device|-d) DEVICE="$2"; shift ;;
    --restore|-r) RESTORE_LOG="$2"; shift ;;
    --list)     MODE="list" ;;
    --version)  echo "$VERSION"; exit 0 ;;
    --help|-h)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "Unknown option: $1  (try --help)" ;;
  esac
  shift
done

ensure_adb

if [ "$MODE" = "list" ]; then
  banner
  i=0
  while [ $i -lt ${#GROUP_KEY[@]} ]; do
    printf '  %s%-32s%s %s\n' "$c_bold" "${GROUP_TITLE[$i]}" "$c_reset" "${GROUP_HINT[$i]}"
    i=$((i + 1))
  done
  exit 0
fi

# ---- connection
if [ -z "$RESTORE_LOG" ]; then
  if [ -z "$DEVICE" ] || [ "$(adb -s "$DEVICE" get-state < /dev/null 2>/dev/null)" != "device" ]; then
    pick_device
  fi
fi

if [ -n "$RESTORE_LOG" ]; then
  banner
  do_restore "$RESTORE_LOG"
  exit 0
fi

device_ready || die "Device not ready."

banner
MODEL=$(adb_ shell getprop ro.product.model | tr -d '\r')
REL=$(adb_ shell getprop ro.build.version.release | tr -d '\r')
say "  Device : ${c_bold}${MODEL:-unknown}${c_reset}  (Android ${REL:-?})  ${c_dim}${DEVICE}${c_reset}"
say ""

# ---- choose mode
if [ -z "$MODE" ]; then
  printf '  Choose a debloat level:\n\n'
  printf '    %s1)%s %sQuick%s     — pure bloat, nothing you use breaks\n' "$c_bold" "$c_reset" "$c_grn" "$c_reset"
  printf '    %s2)%s %sMedium%s    — quick + junk apps, watchfaces, dead LTE stack\n' "$c_bold" "$c_reset" "$c_yel" "$c_reset"
  printf '    %s3)%s %sAdvanced%s  — pick every group yourself\n\n' "$c_bold" "$c_reset" "$c_blu" "$c_reset"
  printf '  Choice [1-3]: '
  IFS= read -r choice
  case "$choice" in
    1) MODE="quick" ;;
    2) MODE="medium" ;;
    3) MODE="advanced" ;;
    *) die "Invalid choice." ;;
  esac
fi

# ---- resolve selection
IDX=""
case "$MODE" in
  quick)  for k in $PRESET_QUICK;  do IDX="$IDX $(group_index "$k")"; done ;;
  medium) for k in $PRESET_MEDIUM; do IDX="$IDX $(group_index "$k")"; done ;;
  advanced)
    if ! tui_multiselect; then
      die "Cancelled."
    fi
    [ -z "${SELECTED:-}" ] && die "Nothing selected."
    IDX="$SELECTED" ;;
esac
IDX="${IDX# }"

PKGS=$(pkgs_for_indexes $IDX)
COUNT=$(printf '%s\n' $PKGS | grep -c .)

say "  Mode   : ${c_bold}${MODE}${c_reset}"
say "  Scope  : ${COUNT} packages"
say ""
printf '%s\n' $PKGS | sed 's/^/    /' | head -60
[ "$COUNT" -gt 60 ] && say "    … and $((COUNT - 60)) more"
say ""
hr

if [ "$DRY_RUN" = 0 ]; then
  confirm "Apply these ${COUNT} changes?" || die "Aborted."
fi

apply_list "$PKGS"
[ "${WANT_TUNE:-0}" = 1 ] && tune

if [ "$DRY_RUN" = 0 ]; then
  say ""
  say "  ${c_bold}Next steps${c_reset}"
  say "    1. Turn OFF ADB debugging + Wireless debugging on the watch"
  say "       (they keep Wi-Fi hot and cost more battery than you saved)"
  say "    2. Reboot the watch"
  say "    3. Optional: ./watch-debloat.sh --restore <log> to undo"
fi
say ""
