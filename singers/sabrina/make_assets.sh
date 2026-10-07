#!/bin/zsh
# 从 source/ 里的原图和原视频生成 Sabrina 的素材到 assets/（全部跑完大概 10 分钟）
# 原素材在 ~/Desktop/自媒体稿件/欧美女歌手桌宠/Sabrina-Joshua-Olivia/素材/，复制进 source/ 时改成了英文名：
#   霍尼：honey1~3.jpg（HTfTm7kWAAA2Dp3、Horny、Horny2）、honeylick.mp4（霍尼舔舌头）、honeyshake.mp4（霍尼露屁股）
#   甜心：sweet0.jpg（绝对主图）、sweet1~7.jpg（小红书那 7 张，按文件名顺序）
#   伪人：fake1~2.jpg
#   主要动作：fountain.mp4（喷泉）、juno.mp4（霍尼系列 70 个 Juno 合集）、manvoice.mp4（展示超绝男人音）、megan.mp4（伪人变脸）
#   第二批（他在对话里发的图）：flip1/flip2.jpg（反转：男人牵她头发 → 她牵男人头发）、albums.png（8 张专辑封面拼图）、
#            duo1~4（匠娅久久合照）、joshua.mp4（Joshua 歌舞青春剪辑，小红书下载）
# work/ 放中间素材（不打进 app）：Joshua 单独那段、合照里分开的两个人、反转的两张贴纸
set -e
cd "$(dirname "$0")"
../../tools/build_tools.sh
T=../../build/tools
mkdir -p assets

# 表情包照片 → 白边贴纸
for f in honey1 honey2 honey3 sweet0 sweet1 sweet2 sweet3 sweet4 sweet5 sweet6 sweet7 fake1 fake2; do $T/stickers source/$f.jpg assets/$f 720; done
# 绝对主图左边加竖排「来支持了」（照小红书那张表情包的样子，字也描白边）
$T/caption assets/sweet0 来支持了 --color "#E8205A"

# 会动的表情包：短视频抠成逐帧动画（画布小一点，桌宠里一直循环，省内存），再描一圈白边（半身，底边不描）
$T/scene source/honeylick.mp4 assets/honeylick --max-height 640 && $T/outline assets/honeylick --bust
$T/scene source/honeyshake.mp4 assets/honeyshake --max-height 640 && $T/outline assets/honeyshake --bust

# 伪人变脸：剧里两个人来回切镜头，切到对手演员的那几段（第 20~47、106~150、177~202、246~287 帧）停在她最后一个表情上，声音照常放
$T/scene source/megan.mp4 assets/megan --hold 20-47,106-150,177-202,246-287

# 超绝男人音：中英字幕压在她腿上 → 认出字幕按句子抠出来放脚下，她身上的字擦掉补平
#   已知问题：后半段身后穿白色睡袍的伴舞贴着她，分人识别分不开，会带进来一部分
$T/scene source/manvoice.mp4 assets/manvoice --subs 0,950,1080,170 --erase-subs --subs-ocr

# 喷泉：水花太多，人、椅子、水柱抠出来是碎的 → 整段放原画面，四周淡出（和 Olivia 的 VMA 砸玻璃后半段一样）
$T/scene source/fountain.mp4 assets/fountain --raw-from 0 --crop 0,250,2160,2950

# Juno 合集：70 段里挑了 15 段（按城市名分段，起止秒数见下面）
#   --drop-front：前排观众的头、手、手机不算她；--erase-static：视频作者加的「北美一巡 / 欧巡」标签和城市名，压在她身上的擦掉
#   有几段前排观众挡得厉害，自动去不掉：用 --exclude "~…@帧范围" 把那几帧画面下半部分很黑的东西去掉
J=(--drop-front --erase-static "!0.35,0.705,0.70,0.775;0.05,0.66,0.95,0.84;0.45,0.83,1.0,0.95")
$T/scene source/juno.mp4 assets/juno01 --from 11.23 --to 15.65 $J    # 底特律
$T/scene source/juno.mp4 assets/juno02 --from 36.40 --to 42.40 $J    # 巴尔的摩
$T/scene source/juno.mp4 assets/juno03 --from 48.00 --to 53.03 $J    # 蒙特利尔
$T/scene source/juno.mp4 assets/juno04 --from 87.83 --to 94.20 $J --exclude "~0,0.55,1,1@160-191;0,0,0.38,1@0-14;0.62,0,1,1@0-14"    # 亚特兰大
$T/scene source/juno.mp4 assets/juno05 --from 112.00 --to 118.77 $J  # 奥斯汀
$T/scene source/juno.mp4 assets/juno06 --from 118.97 --to 123.20 $J --exclude "~0,0.55,1,1@10-30"  # 达拉斯（小仙女）
$T/scene source/juno.mp4 assets/juno07 --from 135.27 --to 141.40 $J  # 温哥华
$T/scene source/juno.mp4 assets/juno08 --from 141.60 --to 146.93 $J  # 西雅图
$T/scene source/juno.mp4 assets/juno09 --from 153.00 --to 158.70 $J --exclude "~0,0.55,1,1@0-10"  # 旧金山
$T/scene source/juno.mp4 assets/juno10 --from 207.37 --to 214.43 $J --exclude "~0,0.5,1,1@80-211"  # 伦敦第一场
$T/scene source/juno.mp4 assets/juno11 --from 292.13 --to 299.97 $J  # 哥本哈根第一场
$T/scene source/juno.mp4 assets/juno12 --from 300.17 --to 306.77 $J  # 哥本哈根第二场
$T/scene source/juno.mp4 assets/juno13 --from 334.53 --to 340.07 $J  # 纽约第二场
$T/scene source/juno.mp4 assets/juno14 --from 345.03 --to 350.50 $J --exclude "~0,0.55,1,1@100-164"  # 纽约第四场（原始人）
$T/scene source/juno.mp4 assets/juno15 --from 350.70 --to 356.90 $J  # 纽约收官场

# ---- 第二批 ----
mkdir -p work
# 匠娅久久：四张合照抠成贴纸（两个人一起）
for f in duo1.webp duo2.png duo3.webp duo4.webp; do $T/stickers source/$f assets/${f%.*} 720; done
# 专辑：从拼图里裁出 8 张封面做成圆角白边小卡片（第二排的 2024、2025 少裁一点，避开拼图上的 logo）
$T/cards source/albums.png assets album2015:3,238,265,298 album2016:273,238,265,298 album2018:543,238,265,298 album2019:813,238,265,298 \
  album2022:3,542,265,281 album2024:273,542,265,270 album2025:543,542,265,270 albumnew:813,542,265,281
# 反转：两张照片抠成贴纸（两个人一起），合成「停住 → 翻过去」的动画，配「嗖」「叮」
$T/stickers source/flip1.jpg work/flip1 720 && $T/stickers source/flip2.jpg work/flip2 720
$T/flipcard work/flip1/frames/000.png work/flip2/frames/000.png assets/reverse
# Joshua 挤进来：Joshua 说「从那天起我每天都在后悔没告诉你」「我也爱你 我爱你」那段（15.2~19.7 秒，一个镜头）
#   底下的中文字幕抠出来，最底下的水印裁掉；描白边和合照贴纸统一
$T/scene source/joshua.mp4 work/joshua --from 15.2 --to 19.7 --crop 0,0,1080,1245 --subs 0,1250,1080,90 --subs-ocr && $T/outline work/joshua --bust
#   合照第一张里的匠妹、娅娅分开抠，Joshua 从下面冒出来把两人挤开
$T/stickers source/duo1.webp work/duo1_sab 720 --person 0 && $T/stickers source/duo1.webp work/duo1_oli 720 --person 1
$T/squeeze work/duo1_sab/frames/000.png work/duo1_oli/frames/000.png work/joshua assets/joshuasqueeze --delay 0.6 --overlap 0.8
