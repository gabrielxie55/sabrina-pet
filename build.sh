#!/bin/zsh
# 打包一个歌手的桌宠：./build.sh olivia
# 读 singers/<歌手>/pet.json5 和 singers/<歌手>/assets，打包成 build/<歌手>/<app 名>.app 和下载用的压缩包
# 录制版：./build.sh olivia --record → build/<歌手>-录制版/<app 名>（录制版）.app，画面里没有署名水印，录视频用（不出压缩包，不发布）
set -e
cd "$(dirname "$0")"
SINGER_DIR="singers/$1"
if [[ -z "$1" || ! -f "$SINGER_DIR/pet.json5" ]]; then
  echo "用法：./build.sh <歌手文件夹名>"
  echo "现有的歌手：$(ls singers | grep -v '^_' | tr '\n' ' ')"
  exit 1
fi
RECORD=""
[[ "$2" == "--record" ]] && RECORD=1
OUT="build/$1${RECORD:+-录制版}"
mkdir -p "$OUT"

# 1. 编译程序：Apple 芯片和 Intel 两个版本，合成一个通用程序（所有歌手共用同一份程序）
for arch in arm64 x86_64; do
  swiftc -O -target $arch-apple-macos13.0 engine/main.swift -o build/DeskPet-$arch
done
NATIVE="build/DeskPet-$(uname -m)"

# 2. 检查配置和素材，读出 app 名字、版本号这些
if ! INFO=$("$NATIVE" --config "$SINGER_DIR/pet.json5" --build-info); then
  echo "$INFO"
  exit 1
fi
eval "$INFO"

# 3. 配置里改了倍速：用 audiofix 把声音重做成这个倍速（变速不变调，从原声重做）
if [[ -n "$FIX_SPEED" ]]; then
  ./tools/build_tools.sh audiofix
  for item in ${(s: :)FIX_SPEED}; do
    ./build/tools/audiofix "$SINGER_DIR/assets/${item%%:*}" "${item#*:}"
  done
  eval "$("$NATIVE" --config "$SINGER_DIR/pet.json5" --build-info)"
fi

# 4. 组装 app
[[ -n "$RECORD" ]] && APP_NAME="$APP_NAME（录制版）"
APP="$OUT/$APP_NAME.app"
rm -rf "$APP" "$OUT/icon.iconset"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUT/icon.iconset"
lipo -create build/DeskPet-arm64 build/DeskPet-x86_64 -output "$APP/Contents/MacOS/$EXE"
cp -R "$SINGER_DIR/assets" "$APP/Contents/Resources/assets"
cp "$SINGER_DIR/pet.json5" "$APP/Contents/Resources/pet.json5"
[[ -n "$RECORD" ]] && echo "录制版：画面里不出现署名水印" > "$APP/Contents/Resources/recording"

# 图标：配置里 icon 那张表情包，放在圆角方块里（底色是配置里的 iconColor，不写是粉色）
swift tools/icon.swift "$SINGER_DIR/assets/$ICON/frames/000.png" "$OUT/icon_1024.png" $ICON_BG 2>/dev/null
for s in 16 32 128 256 512; do
  sips -z $s $s "$OUT/icon_1024.png" --out "$OUT/icon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$OUT/icon_1024.png" --out "$OUT/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$OUT/icon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$EXE</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>NSHumanReadableCopyright</key><string>© $(date +%Y) Gabriel Xie · 小红书 @盖比Gabe</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP"
echo "打包完成：$APP（$SINGER，版本 $VERSION）"

# 5. 发布用的压缩包（放到 GitHub Releases 给别人下载）；录制版不出压缩包
[[ -n "$RECORD" ]] && exit 0
rm -f "$OUT/$ZIP.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$ZIP.zip"
echo "下载包：$OUT/$ZIP.zip"
