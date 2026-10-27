# Deploy Hyakki no Android (USB)

## Status
- Dispositivo conectado: `emulator-5554` (sdk_gphone64_x86_64, x86_64) via ADB `C:\android-sdk\platform-tools\adb.exe`
- Godot: `C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe`
- Projeto: `C:\src\hyakki` (Godot 4.7, package `io.github.netstart.hyakki`)
- Preset export "Android" (debug): `build/hyakki-debug.apk`, arquiteturas arm64-v8a + x86_64
- App anterior instalado com o pacote antigo `dev.hyakki.prototype` (desinstale com `adb uninstall dev.hyakki.prototype`; o pacote atual é `io.github.netstart.hyakki`)

## Todo
- [ ] Exportar APK debug via Godot CLI (`--export-debug "Android" build/hyakki-debug.apk`)
- [ ] Instalar APK no dispositivo (`adb install -r`)
- [ ] Lançar app (`adb shell am start` / monkey)
- [ ] Verificar execução (logs via adb logcat)
