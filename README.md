<div align="center">

# ⌚ watch-debloat

**Debloat a Samsung Galaxy Watch (Wear OS) over wireless ADB — no root, fully reversible.**

`./watch-debloat.sh` → guided pairing → pick a level → done.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Bash](https://img.shields.io/badge/bash-3.2%2B%20%26%20zsh-informational)
![No root](https://img.shields.io/badge/root-required-no-brightgreen)
![Reversible](https://img.shields.io/badge/undo-one%20command-brightgreen)

</div>

---

## Why

A stock Galaxy Watch ships with **241 packages** on a device with **1.4 GB of RAM**.

On an SM-R870 measured before any changes:

| Bloat process | RAM | CPU |
|---|---:|---:|
| Google Play Store (2 processes) | 121.5 MB | 21.9% |
| Google Assistant | 44.1 MB | — |
| Samsung Weather | 37.1 MB | — |
| Music transfer | 30.9 MB | — |
| Samsung Device Health | 29.3 MB | 6.5% |
| Chromecast remote | 25.5 MB | — |
| Voice Recorder | 24.9 MB | — |
| Samsung Pay | 24.6 MB | — |
| Calculator | 22.4 MB | — |
| Spatial Number watchface | — | 9.2% |
| **Total** | **360.3 MB** | **37.6%** |

**360 MB of RAM — a quarter of the entire device — held by things nobody asked for.**
The watch then spends ~14% of its CPU in `kswapd0` reclaiming that memory. That
thrash is what "my watch feels laggy" actually is.

After a full debloat: **241 → 158 packages**, Play Store CPU gone, `kswapd0`
down **88%**, zero crashes.

---

## Requirements

- A Samsung Galaxy Watch running **Wear OS 3.0 or newer**
- A laptop/desktop on the **same Wi-Fi network** as the watch
- `adb` (Android platform-tools)
  - macOS: `brew install --cask android-platform-tools`
  - Debian/Ubuntu: `sudo apt install android-tools-adb`
  - Windows: [download platform-tools](https://developer.android.com/tools/releases/platform-tools)

**No root. No PC companion app. No Odin. Nothing flashed.**

---

## Quick start

```bash
git clone https://github.com/akssmax/watch-debloat.git
cd watch-debloat
./watch-debloat.sh
```

The script walks you through everything: it detects whether you need to pair,
prompts for the two ports, connects, then offers three debloat levels.

---

## Connecting your watch (the fiddly part, explained)

Wear OS wireless debugging has **two different ports** and this trips everyone up.

### 1. Turn on Developer options

```
Settings → About watch → Software information
```

Tap **Software version** 5 times → *"Developer mode enabled"*.

### 2. Turn on the debugging toggles

```
Settings → Developer options
```

- **ADB debugging** → ON
- **Wireless debugging** → ON

### 3. Read the connect port

Stay on the **Wireless debugging** screen. It shows:

```
IP address & port
192.168.1.20:35473        ← this is the CONNECT port
```

### 4. Pair (first time only)

Tap **"Pair new device"**. A new screen appears with a **different port** and a
**6-digit code**:

```
IP address & port      192.168.1.20:39373    ← this is the PAIRING port
Wi-Fi pairing code     077995
```

> ⚠️ **The pairing port is NOT the connect port.** They are different numbers and
> mixing them up is the #1 reason pairing fails.

Run:

```bash
adb pair 192.168.1.20:39373 077995
adb connect 192.168.1.20:35473
adb devices      # should list your watch as "device"
```

> The pairing dialog **expires in about 60 seconds**. Keep the screen awake and
> the watch on its charger. If the watch's Wi-Fi sleeps mid-pairing, wake it and retry.

### The script does this for you

Just run `./watch-debloat.sh` — it asks for the pairing port, code and connect
port and handles the rest.

---

## Debloat levels

### 🔴 Quick — *pure bloat, nothing you use breaks*

Bixby · Samsung telemetry agents · factory/service-mode tools · CTS test stubs ·
store demo loop · partner setup · ad services.

Nothing that a normal person can notice. **Always safe.**

### 🟡 Medium — *quick + the obvious junk*

Everything in Quick, plus: 34 alternate watchfaces · Global Goals face packs ·
bundled fonts · Google extras (Assistant, Chromecast, GoogleCamera, SoundCloud) ·
the dead LTE/IMS stack · Knox enterprise MDM · bundled Outlook & Smart Switch ·
Play Store (disabled, not uninstalled).

Keeps every Samsung first-party app you might actually use.

### 🔵 Advanced — *you pick, group by group*

Launches an interactive multi-select:

```
  [x] Bixby voice assistant                          3 pkg
  [ ] Samsung telemetry & diagnostics                5 pkg
  [ ] Factory / service-mode tools                   8 pkg
  ...

  ↑/↓ move · SPACE toggle · A all · N none · ENTER confirm · Q quit
```

Use ↑/↓ to move, **SPACE** to toggle, **A** to select all, **N** to clear,
**ENTER** to confirm. You get a full package preview and a y/N prompt before
anything is changed.

---

## Safety

Everything uses `pm uninstall --user 0`, which **does not delete anything** from
`/system`. It removes the app for your user only — the APK stays on the read-only
system partition.

Every run writes a log:

```bash
./watch-debloat.sh --restore debloat-20261020-040241.log
```

which runs `cmd package install-existing` / `pm enable` for every package it
touched.

Extra safeguards built in:

- **Your active watchface is auto-detected** (`dumpsys wallpaper`) and can never
  be removed by accident
- **The keyboard is protected** — it is the only IME on most watches; removing it
  breaks all text input including Wi-Fi passwords
- The Play Store is **disabled, not uninstalled**, so it's one command to bring back
- `--dry-run` shows exactly what would happen, changes nothing

```bash
./watch-debloat.sh --dry-run              # preview
./watch-debloat.sh --list                 # show every group and package count
./watch-debloat.sh --device 192.168.1.20:35473   # skip the wizard
./watch-debloat.sh --quick --tune         # quick + performance tuning
```

---

## After you're done

**Turn off ADB debugging and Wireless debugging on the watch.**

They keep the Wi-Fi radio hot and will drain more battery than the debloat saved.

Also on the watch:

- `Battery → Wi-Fi auto` → **off**
- Developer options → *"Turn on Wi-Fi automatically when charging"* → **off**
- `Display → touch screen to wake` → off
- `Accessibility → reduce animations` → **on**
- Reboot the watch to let the removals settle

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `failed to connect: No route to host` | Watch Wi-Fi is asleep. Wake it, keep it on the charger. |
| `protocol fault (couldn't read status message)` | You used the **connect** port for `adb pair`. Use the port from the *Pair new device* screen. |
| `adb pair` says *Successfully paired* but `adb devices` is empty | The **connect** port changed. Re-read it from the Wireless debugging screen. |
| Watch not visible on Wi-Fi | Watch and computer must be on the same network. Disconnect the phone from Wi-Fi if the watch is hopping networks. |
| Everything dropped after a reboot | Wireless debugging ports change on reboot. Re-enable it and re-read the port. Pairing survives. |
| Want Play Store back | `adb shell pm enable --user 0 com.android.vending` |

---

## What's in each group

| Group | Packages | What it does |
|---|---:|---|
| Bixby voice assistant | 3 | Always-listening wake word. Big battery win. |
| Samsung telemetry & diagnostics | 5 | Reports to Samsung. |
| Factory / service-mode tools | 8 | Hidden hardware-test menus. |
| Demo, CTS & provisioning residue | 7 | Store demo loop, test stubs, partner setup. |
| Alternate watchfaces | 30 | Keep at least one analogue + one digital. |
| Global Goals face packs | 5 | Donation faces (`com.samsung.sree.*`). |
| Bundled fonts | 3 | ChocoCooky, CoolJazz, Rosemary. |
| Google extras | 4 | Assistant, Chromecast, GoogleCamera, SoundCloud. |
| LTE / IMS stack | 3 | Dead code on Wi-Fi-only watches (SM-R860/R870). |
| Knox enterprise (MDM) | 2 | Enterprise device management. |
| Bundled third-party apps | 3 | Outlook, Smart Switch ×2. |
| Play Store (disable only) | 1 | ~22% CPU and 121 MB RAM. |
| Samsung apps | 9 | Pay, Music, Buds, SmartThings, Galaxy Store, Weather, Calculator, Voice Recorder, Music transfer. |
| Samsung Find | 1 | Find My Phone. |
| Samsung background sync | 2 | MCFDeviceSync, MdecService. |
| Media session listener | 1 | Detects media playing on your phone. |
| Accessibility & TTS engines | 3 | TalkBack, Samsung TTS, Google TTS. |

---

## Notes & caveats

- Tested on **SM-R870 (Galaxy Watch 4 44mm)**, Wear OS, Android 16, build `R870XXS2JZG3`.
  Package names differ slightly across Wear OS versions — anything not present is
  skipped automatically.
- Removing **Safety & emergency** disables the 5×-power-button emergency call.
- Removing **Accessibility** disables all accessibility menus.
- The **LTE/IMS** group only applies to Wi-Fi-only models (SM-R860/R870). On an
  LTE watch (SM-R875) keep it.
- Battery improvements are **not** a controlled discharge-cycle measurement. Real
  gain depends entirely on how you use the watch.

---

## License

MIT — see [LICENSE](LICENSE).

Debloat ideas and package lists adapted from the community work on
[XDA Developers](https://xdaforums.com/t/debloat-galaxy-watch-4.4324147/) and
[r/GalaxyWatch](https://www.reddit.com/r/GalaxyWatch/).
