#!/usr/bin/env swift
// アプリアイコン (AppIcon.icns) を生成するスクリプト。
// 使い方: swift bundle/make-icon.swift  → bundle/AppIcon.icns を出力
import AppKit

/// 指定ピクセルサイズのアイコン画像を描画して PNG データで返す
func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS 標準の余白 (約10%) を取った角丸スクエア
    let inset = s * 0.0977
    let body = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = CGPath(roundedRect: body, cornerWidth: body.width * 0.2237,
                      cornerHeight: body.width * 0.2237, transform: nil)

    // 影
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03,
                  color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(path); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
    ctx.restoreGState()

    // 背景グラデーション (深い紺 → 青緑)
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs, colors: [
        NSColor(red: 0.07, green: 0.10, blue: 0.27, alpha: 1).cgColor,
        NSColor(red: 0.05, green: 0.45, blue: 0.62, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: body.minX, y: body.maxY),
                           end: CGPoint(x: body.maxX, y: body.minY), options: [])
    // 上部のハイライト
    let gloss = CGGradient(colorsSpace: cs, colors: [
        NSColor.white.withAlphaComponent(0.18).cgColor,
        NSColor.white.withAlphaComponent(0).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gloss, start: CGPoint(x: 0, y: body.maxY),
                           end: CGPoint(x: 0, y: body.midY), options: [])

    // Wi-Fi 風の同心円弧 (中心はやや下)
    let c = CGPoint(x: s / 2, y: s * 0.30)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(s * 0.058)
    let start = CGFloat.pi * 0.25, end = CGFloat.pi * 0.75
    for (i, r) in [0.20, 0.33, 0.46].enumerated() {
        ctx.setAlpha(1.0 - CGFloat(i) * 0.12)
        ctx.addArc(center: c, radius: s * r, startAngle: start, endAngle: end, clockwise: false)
        ctx.strokePath()
    }
    ctx.setAlpha(1)

    // 到達確認を示す緑のドット (メニューバーのドットと対応)
    let dr = s * 0.075
    let dot = CGRect(x: c.x - dr, y: c.y - dr, width: dr * 2, height: dr * 2)
    ctx.setShadow(offset: .zero, blur: s * 0.05,
                  color: NSColor(red: 0.2, green: 1, blue: 0.5, alpha: 0.9).cgColor)
    ctx.setFillColor(NSColor(red: 0.30, green: 0.95, blue: 0.55, alpha: 1).cgColor)
    ctx.fillEllipse(in: dot)
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let out = root.appendingPathComponent("AppIcon.icns").path
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out]
try! p.run(); p.waitUntilExit()
print("wrote \(out)")
