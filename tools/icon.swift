import AppKit
// 用表情包贴纸生成 1024x1024 的 app 图标：圆角方块 + 半身贴纸从底边冒出来
// 用法：icon <贴纸png> <输出png> [底色 #RRGGBB，不写是粉色]
let face = NSImage(contentsOfFile: CommandLine.arguments[1])!
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size)); img.lockFocus()
let inset: CGFloat = 100, box = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let shape = NSBezierPath(roundedRect: box, xRadius: 185, yRadius: 185)
if CommandLine.arguments.count > 3, let v = UInt32(CommandLine.arguments[3].replacingOccurrences(of: "#", with: ""), radix: 16) {
    NSColor(srgbRed: CGFloat(v >> 16 & 0xFF) / 255, green: CGFloat(v >> 8 & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1).setFill()
} else {
    NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.88, alpha: 1).setFill()
}
shape.fill()
shape.addClip()
let w = box.width * 0.92, h = w * face.size.height / face.size.width
face.draw(in: NSRect(x: size / 2 - w / 2, y: box.minY, width: w, height: h))
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
