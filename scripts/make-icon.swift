#!/usr/bin/env swift
import AppKit
import Foundation

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.png"
let width = 1024
let height = 1024

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("could not create bitmap")
}

/// The macOS app-icon grid: an 824pt body centred in a 1024pt canvas.
let bodyInset: CGFloat = 100
let bodyRadius: CGFloat = 185

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let canvas = NSRect(x: 0, y: 0, width: width, height: height)
NSColor.clear.setFill()
canvas.fill()

let body = NSRect(
    x: bodyInset,
    y: bodyInset,
    width: canvas.width - bodyInset * 2,
    height: canvas.height - bodyInset * 2
)
let squircle = NSBezierPath(roundedRect: body, xRadius: bodyRadius, yRadius: bodyRadius)
squircle.addClip()

// Graphite shell, lit from the top like a system utility icon.
let shell = NSGradient(colors: [
    NSColor(calibratedRed: 0.255, green: 0.271, blue: 0.302, alpha: 1),
    NSColor(calibratedRed: 0.118, green: 0.125, blue: 0.141, alpha: 1)
])!
shell.draw(in: body, angle: -90)

let highlight = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.10),
    NSColor.white.withAlphaComponent(0.0)
])!
highlight.draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)

// The notch: a small black pill near the top edge, the app's whole idea in one shape.
let notchRect = NSRect(x: body.midX - 124, y: body.maxY - 132, width: 248, height: 56)
let notch = NSBezierPath(roundedRect: notchRect, xRadius: 28, yRadius: 28)
NSColor(calibratedRed: 0.024, green: 0.027, blue: 0.031, alpha: 1).setFill()
notch.fill()
notch.lineWidth = 1.5
NSColor.white.withAlphaComponent(0.10).setStroke()
notch.stroke()

// A plain down arrow, drawn the way SF Symbols would: round caps, even weight.
let arrow = NSBezierPath()
arrow.lineWidth = 64
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: body.midX, y: body.midY + 172))
arrow.line(to: NSPoint(x: body.midX, y: body.midY - 148))
arrow.move(to: NSPoint(x: body.midX - 106, y: body.midY - 42))
arrow.line(to: NSPoint(x: body.midX, y: body.midY - 158))
arrow.line(to: NSPoint(x: body.midX + 106, y: body.midY - 42))

let arrowShadow = NSShadow()
arrowShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
arrowShadow.shadowBlurRadius = 26
arrowShadow.shadowOffset = NSSize(width: 0, height: -8)
arrowShadow.set()
NSColor(calibratedRed: 0.968, green: 0.973, blue: 0.98, alpha: 1).setStroke()
arrow.stroke()

// Inner rim keeps the body from floating flat against a dark desktop.
NSGraphicsContext.saveGraphicsState()
let rim = NSBezierPath(roundedRect: body.insetBy(dx: 3, dy: 3), xRadius: bodyRadius - 3, yRadius: bodyRadius - 3)
rim.lineWidth = 2
NSColor.white.withAlphaComponent(0.09).setStroke()
rim.stroke()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

let data = rep.representation(using: .png, properties: [:])!
let url = URL(fileURLWithPath: output)
try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
try data.write(to: url)
print("wrote \(output)")
