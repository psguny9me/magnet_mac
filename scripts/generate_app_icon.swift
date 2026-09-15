#!/usr/bin/env swift
// WindowSnap 앱 아이콘 생성 스크립트
// 사용: swift scripts/generate_app_icon.swift [출력 디렉터리]
// macOS 아이콘 규격(1024 캔버스, 824 둥근 사각형 + 그림자)에 맞춰
// AppIcon.appiconset에 필요한 모든 크기의 PNG를 생성합니다.

import AppKit
import CoreGraphics

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "WindowSnap/Resources/Assets.xcassets/AppIcon.appiconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func roundedRect(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// 1024x1024 기준 좌표계로 아이콘을 그립니다.
func drawIcon(in ctx: CGContext) {
    let canvas: CGFloat = 1024
    // macOS 아이콘 그리드: 824pt 둥근 사각형, 캔버스 중앙
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tileRadius: CGFloat = 824 * 0.2237
    let tilePath = roundedRect(tile, tileRadius)

    // 그림자
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(rgb(0x2B4ED8))
    ctx.fillPath()
    ctx.restoreGState()

    // 배경 그라데이션 (위: 밝은 블루 → 아래: 딥 인디고)
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: [rgb(0x5B8CFF), rgb(0x2F55E0), rgb(0x1E2F9E)] as CFArray,
                        locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: canvas - 100),
                           end: CGPoint(x: 512, y: 100), options: [])

    // 은은한 상단 하이라이트
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [rgb(0xFFFFFF, 0.28), rgb(0xFFFFFF, 0.0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 980), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 980), endRadius: 720, options: [])
    ctx.restoreGState()

    // ── 글리프: 화면을 좌/우로 분할해 오른쪽 창이 "스냅"된 모습 ──
    // 화면(모니터) 영역
    let screen = CGRect(x: 212, y: 262, width: 600, height: 500)
    let gap: CGFloat = 26
    let paneW = (screen.width - gap) / 2
    let paneRadius: CGFloat = 44

    let leftPane = CGRect(x: screen.minX, y: screen.minY, width: paneW, height: screen.height)
    let rightPane = CGRect(x: screen.minX + paneW + gap, y: screen.minY, width: paneW, height: screen.height)

    // 왼쪽 패널: 반투명 유리(비어 있는 스냅 영역)
    ctx.saveGState()
    ctx.addPath(roundedRect(leftPane, paneRadius))
    ctx.setFillColor(rgb(0xFFFFFF, 0.22))
    ctx.fillPath()
    ctx.addPath(roundedRect(leftPane.insetBy(dx: 5, dy: 5), paneRadius - 5))
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.55))
    ctx.setLineWidth(10)
    ctx.setLineDash(phase: 0, lengths: [42, 30])
    ctx.setLineCap(.round)
    ctx.strokePath()
    ctx.restoreGState()

    // 오른쪽 패널: 스냅된 실제 창 (흰색, 그림자)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: rgb(0x0B1660, 0.45))
    ctx.addPath(roundedRect(rightPane, paneRadius))
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()

    // 창 타이틀바 (연한 회색 띠) + 신호등 버튼
    ctx.saveGState()
    ctx.addPath(roundedRect(rightPane, paneRadius))
    ctx.clip()
    let barH: CGFloat = 84
    ctx.setFillColor(rgb(0xE9EDF7))
    ctx.fill(CGRect(x: rightPane.minX, y: rightPane.maxY - barH, width: rightPane.width, height: barH))
    let dotY = rightPane.maxY - barH / 2
    let dotR: CGFloat = 15
    for (i, color) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
        let cx = rightPane.minX + 44 + CGFloat(i) * 46
        ctx.setFillColor(rgb(UInt32(color)))
        ctx.fillEllipse(in: CGRect(x: cx - dotR, y: dotY - dotR, width: dotR * 2, height: dotR * 2))
    }
    // 본문 콘텐츠 라인 (텍스트 암시)
    ctx.setFillColor(rgb(0xC9D3EE))
    let lineX = rightPane.minX + 40
    let widths: [CGFloat] = [180, 130, 200, 100]
    for (i, w) in widths.enumerated() {
        let y = rightPane.maxY - barH - 70 - CGFloat(i) * 62
        ctx.addPath(roundedRect(CGRect(x: lineX, y: y, width: w, height: 22), 11))
        ctx.fillPath()
    }
    ctx.restoreGState()

    // 스냅 방향 화살표 (왼쪽 패널 중앙 → 오른쪽): 창이 끌려 들어가는 느낌
    ctx.saveGState()
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.95))
    ctx.setLineWidth(30)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    let ax = leftPane.midX - 40
    let ay = leftPane.midY
    ctx.move(to: CGPoint(x: ax - 70, y: ay))
    ctx.addLine(to: CGPoint(x: ax + 70, y: ay))
    ctx.move(to: CGPoint(x: ax + 10, y: ay + 60))
    ctx.addLine(to: CGPoint(x: ax + 70, y: ay))
    ctx.addLine(to: CGPoint(x: ax + 10, y: ay - 60))
    ctx.strokePath()
    ctx.restoreGState()
}

func render(size: Int, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    let s = CGFloat(size) / 1024
    ctx.scaleBy(x: s, y: s)
    drawIcon(in: ctx)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

// (파일명, 픽셀 크기) — Contents.json과 일치해야 합니다.
let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in outputs {
    render(size: px, to: "\(outDir)/\(name)")
}
