#!/bin/zsh
# 编译素材处理工具到 build/tools/：./tools/build_tools.sh（全部）或 ./tools/build_tools.sh scene audiofix（只编这几个）
# 工具源码要和公共部分拼起来再编译；已经编过、源码没改的会跳过
set -e
cd "$(dirname "$0")/.."
mkdir -p build/tools
typeset -A parts
parts=(
  stickers  "stickers.swift edges.swift.inc"
  scene     "scene.swift edges.swift.inc audio.swift.inc"
  swing     "swing.swift edges.swift.inc audio.swift.inc"
  audiofix  "audiofix.swift audio.swift.inc"
  audioonly "audioonly.swift audio.swift.inc"
  outline   "outline.swift"
  caption   "caption.swift"
  cards     "cards.swift"
  flipcard  "flipcard.swift"
  squeeze   "squeeze.swift"
)
if (( $# )); then names=("$@"); else names=(stickers scene swing audiofix audioonly outline caption cards flipcard squeeze); fi
for t in $names; do
  [[ -z "${parts[$t]}" ]] && { echo "没有这个工具：$t"; exit 1 }
  src="build/tools/$t.swift"
  (cd tools && cat ${(s: :)parts[$t]}) > "$src.new"
  if [[ -x "build/tools/$t" ]] && cmp -s "$src.new" "$src"; then rm "$src.new"; continue; fi
  mv "$src.new" "$src"
  echo "编译工具 $t"
  swiftc -O "$src" -o "build/tools/$t"
done
