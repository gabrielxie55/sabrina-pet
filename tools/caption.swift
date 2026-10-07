import AppKit
import ImageIO

// 给表情包贴纸旁边加一列竖排大字（比如 Sabrina 绝对主图左边的「来支持了」），字也描一圈白边，和贴纸一个样子
// 用法：caption <素材目录> <文字> [--color #E8205A] [--side left|right]
// 会改写 frames/000.png 和 mask.bin（画布加宽放字）；只能跑一次，重做要先用 stickers 重新抠
let args = CommandLine.arguments
let dir = URL(fileURLWithPath: args[1])
let text = Array(args[2])
func opt(_ name: String) -> String? { args.firstIndex(of: name).map { args[$0 + 1] } }
let hex = (opt("--color") ?? "#E8205A").replacingOccurrences(of: "#", with: "")
let v = UInt32(hex, radix: 16)!
let color = NSColor(srgbRed: CGFloat(v >> 16 & 0xFF) / 255, green: CGFloat(v >> 8 & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
let onLeft = (opt("--side") ?? "left") == "left"

let url = dir.appendingPathComponent("frames/000.png")
let src = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(url as CFURL, nil)!, 0, nil)!
let W = src.width, H = src.height
let border = max(4, Int((Double(H) * 0.016).rounded()))      // 白边和贴纸一样粗

// 字：竖排，一列字从她头顶附近排到小腿，占画布高度的 80%
let n = CGFloat(text.count)
let fontSize = CGFloat(H) * 0.8 / (n * 1.04)
let font = NSFont(name: "PingFangSC-Semibold", size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize)
let colW = Int(fontSize * 1.06) + border * 2 + 4
let gap = Int(fontSize * 0.08)
let OW = W + colW + gap, OH = H
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

// 先把字画到单独一层（没有白边），再整层往外扩一圈白边
var textPx = [UInt8](repeating: 0, count: OW * OH * 4)
let tctx = CGContext(data: &textPx, width: OW, height: OH, bitsPerComponent: 8, bytesPerRow: OW * 4, space: sRGB,
                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: tctx, flipped: false)
let x0 = onLeft ? CGFloat(border + 2) : CGFloat(W + gap + border + 2)
let top = CGFloat(OH) * 0.9
for (i, ch) in text.enumerated() {
    let s = NSAttributedString(string: String(ch), attributes: [.font: font, .foregroundColor: color])
    let size = s.size()
    let y = top - CGFloat(i + 1) * fontSize * 1.04
    s.draw(at: NSPoint(x: x0 + (fontSize * 1.06 - size.width) / 2, y: y + (fontSize * 1.04 - size.height) / 2))
}
NSGraphicsContext.restoreGraphicsState()

var offsets: [(Int, Int, Float)] = []
let r = Float(border)
for dy in -border - 1...border + 1 { for dx in -border - 1...border + 1 {
    let d = hypot(Float(dx), Float(dy))
    if d <= r + 1 { offsets.append((dx, dy, min(1, r + 1 - d))) }
} }
var outline = [Float](repeating: 0, count: OW * OH)
for y in 0..<OH { for x in 0..<OW where textPx[(y * OW + x) * 4 + 3] > 100 {
    for (dx, dy, w) in offsets {
        let qx = x + dx, qy = y + dy
        guard qx >= 0, qx < OW, qy >= 0, qy < OH else { continue }
        if outline[qy * OW + qx] < w { outline[qy * OW + qx] = w }
    }
} }

// 合成：原贴纸挪到一边，字和白边放另一边
var px = [UInt8](repeating: 0, count: OW * OH * 4)
let ctx = CGContext(data: &px, width: OW, height: OH, bitsPerComponent: 8, bytesPerRow: OW * 4, space: sRGB,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(src, in: CGRect(x: onLeft ? colW + gap : 0, y: 0, width: W, height: H))
for i in 0..<(OW * OH) {
    let ta = Float(textPx[i * 4 + 3]) / 255, o = outline[i]
    guard ta > 0 || o > 0 else { continue }
    // 先铺白边，再盖上字（预乘过的颜色）
    let wa = o * (1 - ta)
    for c in 0..<3 {
        let under = Float(px[i * 4 + c]) * (1 - ta - wa)
        px[i * 4 + c] = UInt8(min(255, Float(textPx[i * 4 + c]) + 255 * wa + max(0, under)))
    }
    px[i * 4 + 3] = UInt8(min(255, Float(px[i * 4 + 3]) * (1 - ta - wa) + (ta + wa) * 255))
}
let out = ctx.makeImage()!
try! NSBitmapImageRep(cgImage: out).representation(using: .png, properties: [:])!.write(to: url)

// 点击判定用的低清遮罩（和 stickers 工具一样：4 倍缩小，取最不透明的）
let ms = 4, mw = OW / ms, mh = OH / ms
var mask = Data()
for v in [UInt32(mw), UInt32(mh), UInt32(1)] { withUnsafeBytes(of: v.littleEndian) { mask.append(contentsOf: $0) } }
for y in 0..<mh { for x in 0..<mw {
    var best: UInt8 = 0
    for dy in 0..<ms { for dx in 0..<ms { best = max(best, px[((y * ms + dy) * OW + x * ms + dx) * 4 + 3]) } }
    mask.append(best)
} }
try! mask.write(to: dir.appendingPathComponent("mask.bin"))
print("\(dir.lastPathComponent)：\(onLeft ? "左" : "右")边加了「\(String(text))」，画布 \(W)x\(H) → \(OW)x\(OH)")
