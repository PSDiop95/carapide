#!/usr/bin/env bash
# Mesure release à installation neuve. Usage : tools/measure_release.sh "<fonctionnalité>" <effet> [--no-build]
# Build AAB -> APK universel, désinstallation, installation, 1er lancement avec sonde, 5 démarrages à froid.
# Ajoute une ligne à docs/perf_log.md. ATTENTION : la désinstallation efface les données du jeu sur le téléphone.
set -u
LABEL="$1"; EFFECT="$2"; NO_BUILD="${3:-}"
GODOT="${GODOT:-/c/Program Files/Godot/Godot.exe}"
SDK="${ANDROID_SDK:-/c/Users/lenovo/AppData/Local/Android/Sdk}"
ADB="$SDK/platform-tools/adb.exe"
JAVA="${JAVA:-/c/Users/lenovo/AppData/Local/Android/jdk/jdk-17.0.20.1+1/bin/java.exe}"
AAPT2="$SDK/build-tools/35.0.1/aapt2.exe"
# Le jar du cache Gradle n'est pas autonome : classpath reconstruit, sans les sources ni les doublons.
BUNDLETOOL_CP="$(find ~/.gradle/caches/modules-2/files-2.1 -name '*.jar' \( -path '*bundletool/1.18.3*' -o -path '*com.android.tools.build/aapt2-proto*' -o -path '*com.google.guava/guava/*' -o -path '*failureaccess*' -o -path '*com.google.protobuf/protobuf-java/*' -o -path '*protobuf-java-util*' -o -path '*auto-value-annotations*' -o -path '*dagger/*' -o -path '*javax.inject*' -o -path '*jose4j*' -o -path '*slf4j-api*' -o -path '*gson*' -o -path '*com.android.tools/r8*' \) ! -name '*sources*' | while read -r jar; do cygpath -w "$jar"; done | paste -sd ';')"
KEYSTORE="C:/Users/lenovo/AppData/Roaming/Godot/keystores/debug.keystore"
PKG=com.carapide.prototype
ACTIVITY=com.godot.game.GodotAppLauncher
DEVICE_NOTE="A23 3,6 Go (pas la réf. 2 Go)"
cd "$(dirname "$0")/.." || exit 2

if [ "$NO_BUILD" != "--no-build" ]; then
	export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE" GODOT_ANDROID_KEYSTORE_RELEASE_USER=androiddebugkey GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
	rm -f build/carapide_release.aab build/universal.apks build/universal.apk
	timeout 580 "$GODOT" --headless --export-release "Android Release" build/carapide_release.aab > build/export.log 2>&1
	[ -f build/carapide_release.aab ] || { tail -20 build/export.log; echo "ECHEC export"; exit 1; }
	"$JAVA" -cp "$BUNDLETOOL_CP" com.android.tools.build.bundletool.BundleToolMain build-apks --bundle=build/carapide_release.aab --output=build/universal.apks --mode=universal --aapt2="$(cygpath -w "$AAPT2")" \
		--ks="$KEYSTORE" --ks-pass=pass:android --ks-key-alias=androiddebugkey --key-pass=pass:android --overwrite || exit 1
	(cd build && unzip -o -q universal.apks universal.apk) || exit 1
fi
APK_MB="$(awk "BEGIN{printf \"%.1f\", $(stat -c %s build/universal.apk)/1048576}")"

"$ADB" shell input keyevent KEYCODE_WAKEUP
"$ADB" uninstall "$PKG" > /dev/null 2>&1
"$ADB" install -r build/universal.apk > /dev/null || exit 1
"$ADB" logcat -c

# 1er lancement : cache de shaders froid, le pire cas de RAM.
MARKER_DIR="/storage/emulated/0/Android/data/$PKG/files"
"$ADB" shell "mkdir -p $MARKER_DIR && echo $EFFECT > $MARKER_DIR/perf_probe.txt" || exit 1
"$ADB" shell am start -n "$PKG/$ACTIVITY" > /dev/null
RAM_PEAK=0
RESULT=""
for _ in $(seq 1 60); do
	sleep 2
	KB="$("$ADB" shell dumpsys meminfo "$PKG" | tr -d '\r' | awk '/TOTAL PSS:/{print $3; exit}')"
	if [ -n "$KB" ] && [ "$KB" -gt "$RAM_PEAK" ]; then
		RAM_PEAK="$KB"
		"$ADB" shell dumpsys meminfo "$PKG" | tr -d '
' > build/meminfo_peak.txt
	fi
	RESULT="$("$ADB" logcat -d -s godot:I | tr -d '\r' | grep 'CARAPIDE_PERF.*done=1' | tail -1)"
	[ -n "$RESULT" ] && break
done
[ -n "$RESULT" ] || { "$ADB" logcat -d -s godot:E godot:I | tail -30; echo "ECHEC sonde : pas de résultat"; exit 1; }
RAM_MB="$(awk "BEGIN{printf \"%.0f\", $RAM_PEAK/1024}")"
P50="$(echo "$RESULT" | sed -E 's/.*fps_p50=([0-9.]+).*/\1/')"
P5="$(echo "$RESULT" | sed -E 's/.*fps_p5=([0-9.]+).*/\1/')"
DRAWS="$(echo "$RESULT" | sed -E 's/.*draw_peak=([0-9]+).*/\1/')"

# Démarrages à froid : médiane de 5, sans sonde.
"$ADB" shell rm -f "$MARKER_DIR/perf_probe.txt"
# am start -W ne couvre que la première image : le démarrage réel va du START à l'écran interactif, lus dans logcat.
TIMES=()
WINDOW_TIMES=()
for _ in 1 2 3 4 5; do
	"$ADB" shell am force-stop "$PKG"
	sleep 2
	"$ADB" logcat -c
	WINDOW_TIMES+=("$("$ADB" shell am start -W -n "$PKG/$ACTIVITY" | tr -d '\r' | awk '/TotalTime/{print $2}')")
	sleep 5
	TIMES+=("$("$ADB" logcat -d | tr -d '\r' | awk '
		function ms(t) { split(t, p, /[:.]/); return (p[1]*3600 + p[2]*60 + p[3])*1000 + p[4] }
		/START u0.*com.carapide/ && !s { s = ms($2) }
		/CARAPIDE_PERF interactive/ { print ms($2) - s; exit }')")
done
"$ADB" shell am force-stop "$PKG"
START_MS="$(printf '%s\n' "${TIMES[@]}" | sort -n | sed -n 3p)"
COMMIT="$(git rev-parse --short HEAD)$(git diff --quiet -- core game meta services data || echo '+')"

LOG=docs/perf_log.md
if [ ! -f "$LOG" ]; then
	cat > "$LOG" <<'HEAD'
# Journal de performance CARAPIDE

Release, installation neuve, 1er lancement (cache froid) pour FPS, RAM et draw calls. Seuils : APK ≤ 150 Mo (alerte 120), démarrage < 5 s, p50 ≥ 55, p5 ≥ 30, RAM < 350 Mo, draw calls < 120.

| Date | Commit | Fonctionnalité | APK (Mo) | Démarrage (ms, médiane de 5) | FPS p50 | FPS p5 | RAM pic (Mo) | Draw calls pic | Appareil |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
HEAD
fi
LINE="| $(date +%F) | $COMMIT | $LABEL | $APK_MB | $START_MS | $P50 | $P5 | $RAM_MB | $DRAWS | $DEVICE_NOTE |"
[ "${NO_LOG:-}" = "1" ] || echo "$LINE" >> "$LOG"
echo "$LINE"
echo "Interactif : ${TIMES[*]} | am start -W : ${WINDOW_TIMES[*]}"
echo "$RESULT" | sed -E 's/.*(CARAPIDE_PERF)//'
