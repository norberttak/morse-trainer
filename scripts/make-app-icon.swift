#!/usr/bin/env swift
// Generates the 1024×1024 app icons (light, dark, tinted) into the asset catalog.
// Run from the repository root:  swift scripts/make-app-icon.swift
//
// Design: a speech bubble holding Morse "K" (-.-, "over to you") instead of words —
// "Morse Than Words".

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let output = "MorseThanWords/Assets.xcassets/AppIcon.appiconset"

struct Palette {
    var backgroundTop: CGColor?
    var backgroundBottom: CGColor?
    var bubble: CGColor
    var morse: CGColor
}

func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func render(_ palette: Palette, to file: String) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("no context") }

    let s = CGFloat(size)
    // Background (the system applies the rounded mask).
    if let top = palette.backgroundTop, let bottom = palette.backgroundBottom {
        let gradient = CGGradient(colorsSpace: space, colors: [bottom, top] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: s), options: [])
    }

    // Speech bubble (CoreGraphics origin is bottom-left).
    let bubble = CGRect(x: 150, y: 330, width: 724, height: 460)
    let path = CGMutablePath()
    path.addRoundedRect(in: bubble, cornerWidth: 150, cornerHeight: 150)
    path.move(to: CGPoint(x: 300, y: 350))
    path.addLine(to: CGPoint(x: 235, y: 170))
    path.addLine(to: CGPoint(x: 470, y: 340))
    path.closeSubpath()
    context.addPath(path)
    context.setFillColor(palette.bubble)
    context.fillPath()

    // Morse "K": dah dit dah, unit u, dit = circle of diameter u, dah = capsule 3u long.
    let u: CGFloat = 64
    let elements: [CGFloat] = [3, 1, 3]  // lengths in units
    let total = elements.reduce(0, +) + CGFloat(elements.count - 1)  // plus 1u gaps
    var x = bubble.midX - total * u / 2
    let y = bubble.midY - u / 2
    context.setFillColor(palette.morse)
    for length in elements {
        let rect = CGRect(x: x, y: y, width: length * u, height: u)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: u / 2, cornerHeight: u / 2, transform: nil))
        context.fillPath()
        x += (length + 1) * u
    }

    let image = context.makeImage()!
    let url = URL(fileURLWithPath: "\(output)/\(file)")
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("cannot write \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("cannot finalize \(url.path)") }
    print("wrote \(url.path)")
}

try render(Palette(
    backgroundTop: rgb(0x1E3A8A), backgroundBottom: rgb(0x2563EB),
    bubble: rgb(0xFFFFFF), morse: rgb(0x1D4ED8)
), to: "AppIcon.png")

// Dark: deep background, light bubble, bright Morse.
try render(Palette(
    backgroundTop: rgb(0x0B1220), backgroundBottom: rgb(0x172554),
    bubble: rgb(0xE5E7EB), morse: rgb(0x1E40AF)
), to: "AppIcon-Dark.png")

// Tinted: grayscale on black; the system applies the tint.
try render(Palette(
    backgroundTop: rgb(0x000000), backgroundBottom: rgb(0x000000),
    bubble: rgb(0xFFFFFF), morse: rgb(0x000000)
), to: "AppIcon-Tinted.png")
