import AppKit
import AVFoundation
import ImageIO

// 「挤进来」名场面：两个人先并排站着，第三个人（一段抠好的名场面）从下面冒出来，把两人往两边挤开，然后放他自己那段（带声音、带字幕）
// Sabrina 桌宠里：匠妹和娅娅合照，Joshua 冲出来插在中间说「我也爱你 我爱你」
// 用法：squeeze <左边.png> <右边.png> <中间那段的素材目录> <输出目录> [--delay 秒] [--overlap 0.3]
//   左右是 stickers 工具抠好的贴纸（--person 分开的两个人）；中间是 scene 工具抠好的一段（frames、audio.m4a、meta.json、subs）
let args = CommandLine.arguments
func load(_ u: URL) -> CGImage { CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(u as CFURL, nil)!, 0, nil)! }
let L = load(URL(fileURLWithPath: args[1])), R = load(URL(fileURLWithPath: args[2]))
let midDir = URL(fileURLWithPath: args[3]), outDir = URL(fileURLWithPath: args[4])
let delay = args.firstIndex(of: "--delay").map { Double(args[$0 + 1])! } ?? 0.6
let fps = 30.0, sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

let midFiles = try! FileManager.default.contentsOfDirectory(at: midDir.appendingPathComponent("frames"), includingPropertiesForKeys: nil)
    .filter { ["heic", "png"].contains($0.pathExtension) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
let midMeta = (try? JSONSerialization.jsonObject(with: Data(contentsOf: midDir.appendingPathComponent("meta.json")))) as? [String: Any] ?? [:]
let mid0 = load(midFiles[0])
let delayFrames = Int((delay * fps).rounded())
let frameCount = delayFrames + midFiles.count

// 尺寸：两个人缩放到画布高度的 85%，中间那位 95%（凑得更近、更抢镜）
let CH = 820
let sideH = Double(CH) * 0.85, midH = Double(CH) * 0.95
let lw = Double(L.width) * sideH / Double(L.height), rw = Double(R.width) * sideH / Double(R.height)
let mw0 = Double(mid0.width) * midH / Double(mid0.height)
// 一开始两人挨着（右边那位压住左边那位一点点），挤开以后中间空出中间那位的 70% 宽
// --overlap：一开始右边那位压住左边那位多少（按窄的那位的宽度算）；合照里两人贴得越近写得越大
let overlapFrac = args.firstIndex(of: "--overlap").map { Double(args[$0 + 1])! } ?? 0.3
let overlap = min(lw, rw) * overlapFrac, gap = mw0 * 0.62
let startW = lw + rw - overlap, endW = lw + rw + gap
let CW = Int((max(startW, endW, mw0) * 1.06).rounded())
let cx = Double(CW) / 2

let framesDir = outDir.appendingPathComponent("frames")
try? FileManager.default.removeItem(at: outDir)
try! FileManager.default.createDirectory(at: framesDir, withIntermediateDirectories: true)
let ms = 4, mmw = CW / ms, mmh = CH / ms
var maskData = Data()
for v in [UInt32(mmw), UInt32(mmh), UInt32(frameCount)] { withUnsafeBytes(of: v.littleEndian) { maskData.append(contentsOf: $0) } }

func easeOutBack(_ t: Double) -> Double { let c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2) }
func clamp01(_ t: Double) -> Double { max(0, min(1, t)) }
for k in 0..<frameCount {
    let t = Double(k) / fps
    var px = [UInt8](repeating: 0, count: CW * CH * 4)
    let ctx = CGContext(data: &px, width: CW, height: CH, bitsPerComponent: 8, bytesPerRow: CW * 4, space: sRGB,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    // 挤开：从 delay 开始 0.35 秒，带一点回弹；被挤的两人往外歪一下再站直
    let p = clamp01((t - delay) / 0.35)
    let push = p == 0 ? 0 : easeOutBack(p)
    let spread = (endW - startW) / 2 * push
    let tilt = p > 0 ? sin(clamp01((t - delay) / 0.6) * .pi) * 0.06 : 0
    let wobble = t < delay ? sin(t * 9) * 0.008 : 0           // 挤进来之前两人轻轻晃，看起来还在甜蜜合影
    func draw(_ img: CGImage, _ w: Double, _ h: Double, _ left: Double, _ angle: Double) {
        ctx.saveGState()
        ctx.translateBy(x: left + w / 2, y: 0)
        ctx.rotate(by: angle)
        ctx.draw(img, in: CGRect(x: -w / 2, y: 0, width: w, height: h))
        ctx.restoreGState()
    }
    let leftX = cx - startW / 2 - spread, rightX = cx - startW / 2 + lw - overlap + spread
    draw(L, lw, sideH, leftX, tilt + wobble)
    draw(R, rw, sideH, rightX, -tilt + wobble)
    if k >= delayFrames {
        // 中间那位：从画布底下冒上来（0.3 秒），然后放他自己那段
        let img = load(midFiles[k - delayFrames])
        let w = Double(img.width) * midH / Double(img.height)
        let rise = 1 - easeOutBack(clamp01((t - delay) / 0.3))
        ctx.draw(img, in: CGRect(x: cx - w / 2, y: -midH * 0.9 * rise, width: w, height: midH))
    }
    let dest = CGImageDestinationCreateWithURL(framesDir.appendingPathComponent(String(format: "%03d.heic", k)) as CFURL, "public.heic" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
    CGImageDestinationFinalize(dest)
    var m = [UInt8](repeating: 0, count: mmw * mmh)
    for y in 0..<mmh { for x in 0..<mmw {
        var best: UInt8 = 0
        for dy in 0..<ms { for dx in 0..<ms { best = max(best, px[((y * ms + dy) * CW + x * ms + dx) * 4 + 3]) } }
        m[y * mmw + x] = best
    } }
    maskData.append(contentsOf: m)
}
try! maskData.write(to: outDir.appendingPathComponent("mask.bin"))

// 声音：前面空 delay 秒，冒出来时「咻」一下，然后接中间那段的原声
let rate = 44100.0
let midAudio = try! AVAudioFile(forReading: midDir.appendingPathComponent("audio.m4a"))
let mfmt = midAudio.processingFormat
let mbuf = AVAudioPCMBuffer(pcmFormat: mfmt, frameCapacity: AVAudioFrameCount(midAudio.length))!
try! midAudio.read(into: mbuf)
let srate = mfmt.sampleRate, chs = Int(mfmt.channelCount)
let total = Double(frameCount) / fps
let n = Int(total * srate), off = Int(delay * srate)
let fmt = AVAudioFormat(standardFormatWithSampleRate: srate, channels: AVAudioChannelCount(chs))!
let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(n))!
out.frameLength = AVAudioFrameCount(n)
var lp: Float = 0
for c in 0..<chs {
    let dst = out.floatChannelData![c], src = mbuf.floatChannelData![c]
    for i in 0..<n {
        var v: Float = 0
        if i >= off && i - off < Int(mbuf.frameLength) { v += src[i - off] }
        let t = Double(i - off) / srate
        if t >= -0.05 && t < 0.3 {
            let env = Float(sin((t + 0.05) / 0.35 * .pi))
            lp += Float(0.08 + 0.5 * (t + 0.05) / 0.35) * (Float.random(in: -1...1) - lp)
            v += lp * env * 0.6
        }
        dst[i] = max(-1, min(1, v))
    }
}
// 放在一个块里：块结束时文件关闭，m4a 才写完整
do {
    let file = try! AVAudioFile(forWriting: outDir.appendingPathComponent("audio.m4a"),
                                settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: srate, AVNumberOfChannelsKey: chs, AVEncoderBitRateKey: 160_000],
                                commonFormat: .pcmFormatFloat32, interleaved: false)
    try! file.write(from: out)
}

// 字幕：沿用中间那段的字幕图，时间往后挪 delay
var subIndex = [Int](repeating: -1, count: frameCount)
if let si = midMeta["subIndex"] as? [Int] { for (i, v) in si.enumerated() where delayFrames + i < frameCount { subIndex[delayFrames + i] = v } }
let subsSrc = midDir.appendingPathComponent("subs")
if FileManager.default.fileExists(atPath: subsSrc.path) { try! FileManager.default.copyItem(at: subsSrc, to: outDir.appendingPathComponent("subs")) }
// 字幕位置是相对画布底边中点的，两边画布一样高（820），直接沿用
let subs = midMeta["subs"] as? [[String: Int]] ?? []
let meta: [String: Any] = ["width": CW, "height": CH, "fps": fps, "frames": frameCount, "cuts": [delayFrames],
                           "subs": subs, "subIndex": subIndex, "freezeFrom": -1]
try! JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted]).write(to: outDir.appendingPathComponent("meta.json"))
print("挤进来：\(frameCount) 帧（\(String(format: "%.1f", total)) 秒），第 \(delayFrames) 帧冒出来，画布 \(CW)x\(CH)，字幕 \(subs.count) 句")
