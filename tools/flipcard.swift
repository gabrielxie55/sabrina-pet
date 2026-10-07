import AppKit
import AVFoundation
import ImageIO

// 「反转」名场面：先放 A 停一会儿（慢慢推近、最后抖两下吊胃口），像翻牌一样翻过去变成 B，配「嗖」和「叮」
// 用法：flipcard <A.png> <B.png> <输出目录> [--hold-a 秒] [--flip 秒] [--hold-b 秒]
// A、B 一般是 stickers 工具抠好的白边贴纸（assets/xxx/frames/000.png）
// 输出和 scene 工具一样：frames/*.heic、mask.bin、audio.m4a、meta.json（翻过去那一帧记成换镜头，桌宠里会弹一下）
let args = CommandLine.arguments
func opt(_ n: String, _ d: Double) -> Double { args.firstIndex(of: n).map { Double(args[$0 + 1])! } ?? d }
func load(_ p: String) -> CGImage { CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath: p) as CFURL, nil)!, 0, nil)! }
let A = load(args[1]), B = load(args[2])
let outDir = URL(fileURLWithPath: args[3])
let holdA = opt("--hold-a", 2.2), flip = opt("--flip", 0.5), holdB = opt("--hold-b", 3.0)
let fps = 30.0
let total = holdA + flip + holdB
let frameCount = Int((total * fps).rounded())

// 画布：两张都缩放到同样高度，底边贴地；四周留一点余量给推近和弹一下
let CH = 820, bodyH = Double(CH) * 0.9
func size(_ img: CGImage) -> (Double, Double) { (Double(img.width) * bodyH / Double(img.height), bodyH) }
let (aw, ah) = size(A), (bw, bh) = size(B)
let CW = Int((max(aw, bw) * 1.12).rounded())
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

let framesDir = outDir.appendingPathComponent("frames")
try? FileManager.default.removeItem(at: outDir)
try! FileManager.default.createDirectory(at: framesDir, withIntermediateDirectories: true)
let ms = 4, mw = CW / ms, mh = CH / ms
var maskData = Data()
for v in [UInt32(mw), UInt32(mh), UInt32(frameCount)] { withUnsafeBytes(of: v.littleEndian) { maskData.append(contentsOf: $0) } }

func ease(_ t: Double) -> Double { t * t * (3 - 2 * t) }
let flipFrame = Int(((holdA + flip / 2) * fps).rounded())
for k in 0..<frameCount {
    let t = Double(k) / fps
    var px = [UInt8](repeating: 0, count: CW * CH * 4)
    let ctx = CGContext(data: &px, width: CW, height: CH, bitsPerComponent: 8, bytesPerRow: CW * 4, space: sRGB,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    let cx = Double(CW) / 2
    var img = A, w = aw, h = ah, sx = 1.0, s = 1.0, rot = 0.0
    if t < holdA {
        s = 1 + 0.035 * ease(t / holdA)                      // 慢慢推近
        if t > holdA - 0.45 { rot = sin((t - holdA) * 55) * 0.025 }   // 翻之前抖两下
    } else if t < holdA + flip {
        let p = (t - holdA) / flip
        s = 1.035
        if p < 0.5 { sx = cos(p * .pi) } else { img = B; w = bw; h = bh; sx = -cos(p * .pi); s = 1.0 }
    } else {
        img = B; w = bw; h = bh
        let p = (t - holdA - flip) / 0.35
        s = p < 1 ? 1 + 0.08 * sin(p * .pi) * (1 - p) : 1  // 翻过来弹一下
    }
    ctx.saveGState()
    ctx.translateBy(x: cx, y: 0)
    ctx.rotate(by: rot)
    ctx.scaleBy(x: s * max(0.001, sx), y: s)
    ctx.draw(img, in: CGRect(x: -w / 2, y: 0, width: w, height: h))
    ctx.restoreGState()
    let dest = CGImageDestinationCreateWithURL(framesDir.appendingPathComponent(String(format: "%03d.heic", k)) as CFURL, "public.heic" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
    CGImageDestinationFinalize(dest)
    // 点击判定用的低清遮罩：CGContext 的像素是从上往下存的
    var m = [UInt8](repeating: 0, count: mw * mh)
    for y in 0..<mh { for x in 0..<mw {
        var best: UInt8 = 0
        for dy in 0..<ms { for dx in 0..<ms { best = max(best, px[((y * ms + dy) * CW + x * ms + dx) * 4 + 3]) } }
        m[y * mw + x] = best
    } }
    maskData.append(contentsOf: m)
}
try! maskData.write(to: outDir.appendingPathComponent("mask.bin"))

// 声音：翻的时候「嗖」一下（越来越高的风声），翻过来「叮」一声
let rate = 44100.0, n = Int(total * rate)
var pcm = [Float](repeating: 0, count: n)
var lp: Float = 0
for i in 0..<n {
    let t = Double(i) / rate
    if t >= holdA - 0.05 && t < holdA + flip {
        let p = (t - holdA + 0.05) / (flip + 0.05)
        let env = Float(sin(p * .pi))
        let a = Float(0.05 + 0.4 * p)                      // 低通越来越亮：声音从低往高
        lp += a * (Float.random(in: -1...1) - lp)
        pcm[i] += lp * env * 0.9
    }
    let td = t - (holdA + flip / 2)
    if td >= 0 {
        let env = Float(exp(-td * 5))
        pcm[i] += env * 0.35 * Float(sin(2 * .pi * 1318.5 * td) + 0.6 * sin(2 * .pi * 1975.5 * td) + 0.3 * sin(2 * .pi * 2637 * td))
    }
}
let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(n))!
buf.frameLength = AVAudioFrameCount(n)
for i in 0..<n { buf.floatChannelData![0][i] = max(-1, min(1, pcm[i])) }
// 放在一个块里：块结束时文件关闭，m4a 才写完整
do {
    let file = try! AVAudioFile(forWriting: outDir.appendingPathComponent("audio.m4a"),
                                settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 128_000],
                                commonFormat: .pcmFormatFloat32, interleaved: false)
    try! file.write(from: buf)
}

let meta: [String: Any] = ["width": CW, "height": CH, "fps": fps, "frames": frameCount, "cuts": [flipFrame],
                           "subs": [] as [Any], "subIndex": [Int](repeating: -1, count: frameCount), "freezeFrom": -1]
try! JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted]).write(to: outDir.appendingPathComponent("meta.json"))
print("反转：\(frameCount) 帧（\(String(format: "%.1f", total)) 秒），第 \(flipFrame) 帧翻过去，画布 \(CW)x\(CH)")
