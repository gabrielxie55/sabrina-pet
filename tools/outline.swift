import AppKit
import ImageIO

// 给会动的表情包（scene 工具从短视频抠出来的逐帧动画）每一帧描一圈白边，和照片抠的贴纸一个样子
// 用法：outline <素材目录> [--bust]
//   --bust：半身（她被画面底边切断），底边不描白边，在桌宠里贴着地面「冒出来」
// 会改写 frames/*.heic、mask.bin，meta.json 里的画布大小也跟着改；画布四周会加宽一圈放白边
// 只能跑一次（再跑会再描一圈）：要重做就先用 scene 重新抠

let args = CommandLine.arguments
let dir = URL(fileURLWithPath: args[1])
let bust = args.contains("--bust")
let framesDir = dir.appendingPathComponent("frames")
let files = try! FileManager.default.contentsOfDirectory(at: framesDir, includingPropertiesForKeys: nil)
    .filter { ["png", "heic"].contains($0.pathExtension) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func load(_ url: URL) -> CGImage {
    let src = CGImageSourceCreateWithURL(url as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(src, 0, nil)!
}
let first = load(files[0])
let W = first.width, H = first.height
let border = max(4, Int((Double(H) * 0.016).rounded()))      // 白边粗细：和贴纸一样，按高度的 1.6%
let pad = border + 2
let OW = W + pad * 2, OH = H + pad + (bust ? 0 : pad)
// 画布里的偏移（像素行从上往下数）：上、左、右都加 pad，半身的底下不加
let ox = pad, oy = pad

var offsets: [(Int, Int, Float)] = []
let r = Float(border)
for dy in -border - 1...border + 1 { for dx in -border - 1...border + 1 {
    let d = hypot(Float(dx), Float(dy))
    if d <= r + 1 { offsets.append((dx, dy, min(1, r + 1 - d))) }    // 最外一圈半透明，边缘不起锯齿
} }

let ms = 4, mw = OW / ms, mh = OH / ms
var maskData = Data()
for v in [UInt32(mw), UInt32(mh), UInt32(files.count)] { withUnsafeBytes(of: v.littleEndian) { maskData.append(contentsOf: $0) } }

for url in files {
    let img = load(url)
    // 读成「不预乘」的 RGBA，原图放在新画布里偏移 (ox, oy) 的位置
    var src = [UInt8](repeating: 0, count: OW * OH * 4)
    let ctx = CGContext(data: &src, width: OW, height: OH, bitsPerComponent: 8, bytesPerRow: OW * 4, space: sRGB,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: ox, y: OH - oy - H, width: W, height: H))
    // 和她不连着的零碎小块（旁边的人露出来的一点手臂、衣角）去掉：只留最大的那块，和面积超过它 15% 的块
    var label = [Int32](repeating: 0, count: OW * OH)
    var sizes: [Int] = [0]
    for start in 0..<(OW * OH) where src[start * 4 + 3] > 40 && label[start] == 0 {
        let id = Int32(sizes.count)
        var stack = [start], n = 0
        label[start] = id
        while let p = stack.popLast() {
            n += 1
            let x = p % OW, y = p / OW
            for q in [x > 0 ? p - 1 : -1, x < OW - 1 ? p + 1 : -1, y > 0 ? p - OW : -1, y < OH - 1 ? p + OW : -1]
                where q >= 0 && label[q] == 0 && src[q * 4 + 3] > 40 {
                label[q] = id
                stack.append(q)
            }
        }
        sizes.append(n)
    }
    if let biggest = sizes.max(), biggest > 0 {
        for i in 0..<(OW * OH) where label[i] > 0 && Double(sizes[Int(label[i])]) < 0.15 * Double(biggest) {
            src[i * 4] = 0; src[i * 4 + 1] = 0; src[i * 4 + 2] = 0; src[i * 4 + 3] = 0
        }
    }
    var outline = [Float](repeating: 0, count: OW * OH)
    for y in 0..<OH { for x in 0..<OW where src[(y * OW + x) * 4 + 3] > 128 {
        for (dx, dy, w) in offsets {
            let qx = x + dx, qy = y + dy
            guard qx >= 0, qx < OW, qy >= 0, qy < OH else { continue }
            if outline[qy * OW + qx] < w { outline[qy * OW + qx] = w }
        }
    } }
    if bust {
        // 半身：最底下几行不描边，免得贴着地面那条线上有一道白
        for y in (OH - border - 1)..<OH { for x in 0..<OW { outline[y * OW + x] = min(outline[y * OW + x], Float(src[(y * OW + x) * 4 + 3]) / 255) } }
    }
    var px = [UInt8](repeating: 0, count: OW * OH * 4)
    var m = [UInt8](repeating: 0, count: mw * mh)
    for i in 0..<(OW * OH) {
        let a = Float(src[i * 4 + 3]) / 255, o = outline[i]
        let outA = a + o * (1 - a)
        guard outA > 0.004 else { continue }
        // 预乘过的颜色 + 白边（白色 × 白边不透明度 × 没被身体盖住的部分）
        for c in 0..<3 { px[i * 4 + c] = UInt8(min(255, Float(src[i * 4 + c]) + 255 * o * (1 - a))) }
        px[i * 4 + 3] = UInt8(outA * 255)
        let mx = (i % OW) / ms, my = (i / OW) / ms
        if mx < mw, my < mh { m[my * mw + mx] = max(m[my * mw + mx], px[i * 4 + 3]) }
    }
    let out = CGContext(data: &px, width: OW, height: OH, bitsPerComponent: 8, bytesPerRow: OW * 4, space: sRGB,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let heic = url.deletingPathExtension().appendingPathExtension("heic")
    if url.pathExtension != "heic" { try? FileManager.default.removeItem(at: url) }
    let dest = CGImageDestinationCreateWithURL(heic as CFURL, "public.heic" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, out.makeImage()!, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
    CGImageDestinationFinalize(dest)
    maskData.append(contentsOf: m)
}
try! maskData.write(to: dir.appendingPathComponent("mask.bin"))
let metaURL = dir.appendingPathComponent("meta.json")
var meta = (try? Data(contentsOf: metaURL)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
meta["width"] = OW
meta["height"] = OH
meta["outline"] = border
try! JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted]).write(to: metaURL)
print("\(dir.lastPathComponent)：\(files.count) 帧描了 \(border) 像素白边，画布 \(W)x\(H) → \(OW)x\(OH)\(bust ? "（半身，底边不描）" : "")")
