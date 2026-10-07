#!/bin/zsh
# 新建一个歌手：./new_singer.sh sabrina
# 建好 singers/<英文名>/ 文件夹：配置模板 pet.json5、素材处理脚本 make_assets.sh、空的 assets/ 和 source/
set -e
cd "$(dirname "$0")"
NAME="$1"
if [[ -z "$NAME" || ! "$NAME" =~ ^[a-z0-9]+$ ]]; then
  echo "用法：./new_singer.sh <英文名，小写字母和数字>，比如 ./new_singer.sh sabrina"
  exit 1
fi
DIR="singers/$NAME"
if [[ -e "$DIR" ]]; then echo "$DIR 已经有了，不覆盖"; exit 1; fi
mkdir -p "$DIR/assets" "$DIR/source"
cp singers/_template/pet.json5 "$DIR/pet.json5"
cat > "$DIR/make_assets.sh" <<'EOF'
#!/bin/zsh
# 从 source/ 里的原图和原视频生成素材到 assets/
# 每处理一段就把命令写进来，前面加一行中文注释说明为什么用这些参数，以后能一键重做
# 倍速不用写在这里：写在 pet.json5 的 speed，打包时自动处理
set -e
cd "$(dirname "$0")"
../../tools/build_tools.sh
T=../../build/tools
mkdir -p assets

# 表情包：照片抠成白边贴纸，比如
# $T/stickers source/meme1.jpg assets/meme1 720

# 名场面：视频抠成透明逐帧动画，比如
# $T/scene source/xxx.mp4 assets/xxx --crop 0,661,1080,585

# 只要声音的，比如
# $T/audioonly source/live.mov assets/live
EOF
chmod +x "$DIR/make_assets.sh"
echo "建好了：$DIR"
echo "下一步：原图原视频放进 $DIR/source/，处理成素材放进 $DIR/assets/，再改 $DIR/pet.json5"
