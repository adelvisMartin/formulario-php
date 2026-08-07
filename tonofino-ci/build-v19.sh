#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD"
PROJECT="$ROOT/tonofino-android"
ARTIFACTS="$ROOT/artifacts"

rm -rf "$PROJECT" "$ARTIFACTS" tonofino-android.zip tonofino-v1.7.patch tonofino-v1.8.patch* tonofino-v1.9.patch* java-test tonofino-brand-icon.png

# Reconstruct the verified Android source used by TonoFino 1.8.
cat tonofino-ci/chunk_0?.b64 tonofino-ci/chunk_1[0-7].b64 | base64 -d > tonofino-android.zip
cat tonofino-ci/chunk_{18..27}.bin >> tonofino-android.zip
test "$(sha256sum tonofino-android.zip | cut -d' ' -f1)" = "5819adc3a83f9f03f9c87a4afb6f21ce6d71501b6b2835bcb78172488dd00fce"
mkdir "$PROJECT"
unzip -q tonofino-android.zip -d "$PROJECT"

base64 -d tonofino-ci/tonofino-v1.7.patch.gz.b64 | gzip -dc > tonofino-v1.7.patch
git -C "$PROJECT" init -q
git -C "$PROJECT" apply --check ../tonofino-v1.7.patch
git -C "$PROJECT" apply ../tonofino-v1.7.patch
sed -i 's/android.useAndroidX=false/android.useAndroidX=true/' "$PROJECT/gradle.properties"

cat tonofino-ci/v18_complete_{00..06}.txt | base64 -d > tonofino-v1.8.patch.gz
test "$(sha256sum tonofino-v1.8.patch.gz | cut -d' ' -f1)" = "54e5f0d742d2abeb5c1a6603eca13e884cd04925e90915a971d2b0589aeb5f48"
gzip -dc tonofino-v1.8.patch.gz > tonofino-v1.8.patch
git -C "$PROJECT" apply --check ../tonofino-v1.8.patch
git -C "$PROJECT" apply ../tonofino-v1.8.patch
sed -i '/setPerformanceMode(AudioRecord.PERFORMANCE_MODE_LOW_LATENCY)/d' "$PROJECT/app/src/main/java/com/tonofino/studio/NativeTunerEngine.java"

# Apply the complete Studio UI/feature upgrade. Native tuned feedback is already
# part of the v1.9 patch; normalize its delayed release for this activity.
cat tonofino-ci/v19_part_{00..07}.txt | base64 -d > tonofino-v1.9.patch.gz
test "$(sha256sum tonofino-v1.9.patch.gz | cut -d' ' -f1)" = "b9fb7bbd067949f9b7a6940a5835312915bcbe617c584565c53888fc528b537a"
gzip -dc tonofino-v1.9.patch.gz > tonofino-v1.9.patch
git -C "$PROJECT" apply --check --whitespace=nowarn ../tonofino-v1.9.patch
git -C "$PROJECT" apply --whitespace=nowarn ../tonofino-v1.9.patch
python3 tonofino-ci/fix-mainactivity-v19.py "$PROJECT/app/src/main/java/com/tonofino/studio/MainActivity.java"

mkdir -p "$PROJECT/app/src/main/assets/public/assets" "$PROJECT/app/src/main/assets/public/js" "$PROJECT/app/src/main/res/drawable-nodpi"
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  mkdir -p "$PROJECT/app/src/main/res/mipmap-${density}"
done

base64 -d tonofino-ci/v19-brand-icon.png.b64 > tonofino-brand-icon.png
test "$(sha256sum tonofino-brand-icon.png | cut -d' ' -f1)" = "dc736bdbb78fdcd35c028712cf29a46e1e01565c1c32a87dddb26a304b9c1bd0"
cp tonofino-brand-icon.png "$PROJECT/app/src/main/assets/public/assets/brand-icon.png"
cp tonofino-brand-icon.png "$PROJECT/app/src/main/assets/public/assets/icon-192.png"
cp tonofino-brand-icon.png "$PROJECT/app/src/main/assets/public/assets/icon-512.png"
cp tonofino-brand-icon.png "$PROJECT/app/src/main/assets/public/assets/og-image.png"
cp tonofino-brand-icon.png "$PROJECT/app/src/main/res/drawable-nodpi/ic_launcher_foreground_brand.png"
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  cp tonofino-brand-icon.png "$PROJECT/app/src/main/res/mipmap-${density}/ic_launcher.png"
  cp tonofino-brand-icon.png "$PROJECT/app/src/main/res/mipmap-${density}/ic_launcher_round.png"
done
cp tonofino-ci/studio-core-v19.js "$PROJECT/app/src/main/assets/public/js/studio-core.js"
test "$(sha256sum "$PROJECT/app/src/main/assets/public/js/studio-core.js" | cut -d' ' -f1)" = "f8e6218360aa4a04155ce73e5b093eb2850e9f7ac690e65bf74c8e02a382d1b1"

# Static feature contract.
grep -q "versionCode 19" "$PROJECT/app/build.gradle"
grep -q "versionName '1.9.0'" "$PROJECT/app/build.gradle"
grep -q "playTunedFeedback" "$PROJECT/app/src/main/java/com/tonofino/studio/MainActivity.java"
grep -q "class MetronomeEngine" "$PROJECT/app/src/main/assets/public/js/audio-engine.js"
grep -q "studio-core.js" "$PROJECT/app/src/main/assets/public/service-worker.js"
grep -q "brand-icon.png" "$PROJECT/app/src/main/assets/public/js/app.js"
grep -q "scheduleAheadTime" "$PROJECT/app/src/main/assets/public/js/audio-engine.js"
grep -q "AFINADA" "$PROJECT/app/src/main/assets/public/js/app.js"
grep -q "fretboard" "$PROJECT/app/src/main/assets/public/js/app.js"
test -s "$PROJECT/app/src/main/assets/public/assets/brand-icon.png"
test -s "$PROJECT/app/src/main/assets/public/assets/icon-512.png"

# Detector and bridge regression tests.
mkdir -p java-test
javac -d java-test "$PROJECT/app/src/main/java/com/tonofino/studio/PitchDetector.java" "$PROJECT/qa/PitchDetectorSelfTest.java"
java -cp java-test PitchDetectorSelfTest
sed -i "s#/mnt/data/tonofino_v18_work/android#$PROJECT#" "$PROJECT/qa/native-audio-bridge-test.mjs"
node "$PROJECT/qa/native-audio-bridge-test.mjs"
find "$PROJECT/app/src/main/assets/public/js" -maxdepth 1 -name '*.js' -print0 | xargs -0 -n1 node --check

# Android build.
yes | sdkmanager --licenses >/dev/null || true
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"
echo "sdk.dir=$ANDROID_SDK_ROOT" > "$PROJECT/local.properties"
gradle -p "$PROJECT" assembleDebug --no-daemon --stacktrace

# Binary verification and delivery bundle.
mkdir -p "$ARTIFACTS"
cp "$PROJECT/app/build/outputs/apk/debug/app-debug.apk" "$ARTIFACTS/TonoFino-Studio-v1.9.0-debug.apk"
"$ANDROID_SDK_ROOT/build-tools/36.0.0/apksigner" verify --verbose --print-certs "$ARTIFACTS/TonoFino-Studio-v1.9.0-debug.apk" > "$ARTIFACTS/apksigner.txt"
"$ANDROID_SDK_ROOT/build-tools/36.0.0/aapt2" dump badging "$ARTIFACTS/TonoFino-Studio-v1.9.0-debug.apk" > "$ARTIFACTS/apk-badging.txt"
grep -q "package: name='com.tonofino.studio.debug'" "$ARTIFACTS/apk-badging.txt"
grep -q "versionCode='19'" "$ARTIFACTS/apk-badging.txt"
grep -q "versionName='1.9.0-debug'" "$ARTIFACTS/apk-badging.txt"
grep -q "sdkVersion:'26'" "$ARTIFACTS/apk-badging.txt"
grep -q "targetSdkVersion:'36'" "$ARTIFACTS/apk-badging.txt"
unzip -t "$ARTIFACTS/TonoFino-Studio-v1.9.0-debug.apk" > "$ARTIFACTS/apk-integrity.txt"
unzip -l "$ARTIFACTS/TonoFino-Studio-v1.9.0-debug.apk" | grep -q 'assets/public/js/studio-core.js'
unzip -l "$ARTIFACTS/TonoFino-Studio-v1.9.0-debug.apk" | grep -q 'assets/public/assets/brand-icon.png'
sha256sum "$ARTIFACTS/TonoFino-Studio-v1.9.0-debug.apk" > "$ARTIFACTS/TonoFino-Studio-v1.9.0-debug.apk.sha256"
zip -qr "$ARTIFACTS/TonoFino-Studio-v1.9.0-android-source.zip" tonofino-android
