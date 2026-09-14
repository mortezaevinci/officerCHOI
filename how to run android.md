# How to run on Android

## The short version

```bash
bash /mnt/c/temp/_script/run-android.sh --build --shot
```

That builds the APK, starts the emulator if it is not already running, waits
for it, installs, launches, and saves a screenshot to
`preview\android_screen.png`.

Drop `--build` if the APK is already current. Drop `--shot` if you do not need
the screenshot.

---

## The three steps, if you would rather do them yourself

### 1. Build the APK

```powershell
cd C:\temp\officerchoi
tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless ^
  --path game --export-debug Android build\android\OfficerChoi.apk
```

Output: `build\android\OfficerChoi.apk` (~112 MB, signed, runs on both the
emulator and a real phone).

> **Use `tools\godot\`, not `tools\godot-mono\`.** `build.ps1` uses the .NET
> editor for Windows and Linux, but it cannot export Android here: Godot
> rejects a net8.0 C# project against a net9.0 Android template. The C# in this
> project is only the `godot_mcp` editor addon - no gameplay code, and the
> export already excludes it - so Android does not need the .NET editor at all.

### 2. Start the emulator

```
C:\temp\_script\bootemu2.bat
```

**Use that script, or pass `-gpu host` yourself.** With software rendering the
game launches and draws a completely black screen, because SwiftShader cannot
link Godot's canvas shader (it exceeds the fragment uniform limit). The process
runs, nothing appears, and nothing obviously fails.

### 3. Install and launch

```bash
ADB=/mnt/c/Users/morte/AppData/Local/Android/Sdk/platform-tools/adb.exe
"$ADB" -s emulator-5554 install -r 'C:\temp\officerchoi\build\android\OfficerChoi.apk'
"$ADB" -s emulator-5554 shell monkey -p com.example.officerchoi -c android.intent.category.LAUNCHER 1
```

---

## Running on a real phone instead

Turn on Developer Options and USB debugging, plug it in, then:

```bash
"$ADB" devices                      # find its serial
"$ADB" -s <serial> install -r 'C:\temp\officerchoi\build\android\OfficerChoi.apk'
```

No emulator needed. The APK carries both `arm64-v8a` and `x86_64`, so the same
file works on a phone and on the emulator.

---

## Things that will confuse you

**`adb devices` shows a device you do not have.**

```
emulator-5562   offline
```

That is not an emulator. `NTKDaemon` (Nahimic audio software, bundled with MSI
and Killer network hardware) listens on port 5563, and adb scans ports
5554-5584 looking for emulators and assumes it found one. Always name the real
device with `-s emulator-5554`, or an install can go to the phantom.

**The game launches but the screen is black.** Software rendering. Restart the
emulator with `-gpu host`. Confirm with:

```bash
"$ADB" -s emulator-5554 logcat -d | grep -i GL_MAX_FRAGMENT_UNIFORM_VECTORS
```

If that matches, it is the GPU, not your code.

**`am start` says "Permission Denial: not exported".** Expected. Launch through
the launcher intent with `monkey`, as above, rather than naming the activity.

**Windows cannot download anything** - winget, curl.exe and PowerShell all fail
instantly while WSL works fine. Windscribe VPN is the likely cause. Download
through WSL into the Windows filesystem instead. Java is unaffected, which is
why `sdkmanager` works.

---

## Seeing what the app is actually doing

```bash
"$ADB" -s emulator-5554 logcat -d | grep -i godot | tail -30
"$ADB" -s emulator-5554 shell pidof com.example.officerchoi     # alive?
"$ADB" -s emulator-5554 exec-out screencap -p > shot.png        # screenshot
```

A healthy launch shows `OnGodotSetupCompleted`, `OnGodotMainLoopStarted`, and
an `OpenGL API OpenGL ES 3.1 ... NVIDIA GeForce GTX 1660 Ti` line.

---

## Before you ship

The package id is still `com.example.officerchoi`. **Google Play rejects
anything starting `com.example.`**, so it needs a real id, set in
`game\export_presets.cfg` under `package/unique_name`.

Google Play also wants an `.aab`, not an `.apk`. That needs
`gradle_build/use_gradle_build=true` and a gradle setup, which is not
configured here - the current preset builds an APK deliberately, because that
is what you can actually install and test.
