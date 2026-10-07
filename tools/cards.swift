import AppKit
import ImageIO

// 从一张拼图里裁出几块，做成带圆角、白边的小卡片（比如 Sabrina 的专辑封面）
// 用法：cards <图片> <assets目录> 名字:x,y,w,h …（像素，y 从顶部算）
// 每张输出 <assets目录>/<名字>/frames/000.png + mask.bin，和贴纸一个格式
let args = CommandLine.arguments
let src = NSImage(contentsOfFile: args[1])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let outRoot = URL(fileURLWithPath: args[2])
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

for item in args[3...] {
    let p = item.split(separator: ":")
    let name = String(p[0]), v = p[1].split(separator: ",").map { Int($0)! }
    let rect = CGRect(x: v[0], y: v[1], width: v[2], height: v[3])
    guard let tile = src.cropping(to: rect) else { continue }
    let border = max(4, Int(Double(v[3]) * 0.025)), radius = CGFloat(v[3]) * 0.07
    let W = v[2] + border * 2, H = v[3] + border * 2
    var px = [UInt8](repeating: 0, count: W * H * 4)
    let ctx = CGContext(data: &px, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: sRGB,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // 白色圆角底（白边），里面放裁出来的封面，也切圆角
    ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: W, height: H), cornerWidth: radius + CGFloat(border), cornerHeight: radius + CGFloat(border), transform: nil))
    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
    ctx.fillPath()
    let inner = CGRect(x: border, y: border, width: v[2], height: v[3])
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: inner, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    ctx.draw(tile, in: inner)
    ctx.restoreGState()
    let dir = outRoot.appendingPathComponent(name)
    try? FileManager.default.removeItem(at: dir)
    try! FileManager.default.createDirectory(at: dir.appendingPathComponent("frames"), withIntermediateDirectories: true)
    try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
        .write(to: dir.appendingPathComponent("frames/000.png"))
    let ms = 4, mw = W / ms, mh = H / ms
    var mask = Data()
    for n in [UInt32(mw), UInt32(mh), UInt32(1)] { withUnsafeBytes(of: n.littleEndian) { mask.append(contentsOf: $0) } }
    for y in 0..<mh { for x in 0..<mw {
        var best: UInt8 = 0
        for dy in 0..<ms { for dx in 0..<ms { best = max(best, px[((y * ms + dy) * W + x * ms + dx) * 4 + 3]) } }
        mask.append(best)
    } }
    try! mask.write(to: dir.appendingPathComponent("mask.bin"))
    print("\(name)：\(W)x\(H)")
}
