import SwiftUI
import AppKit
import ApplicationServices

enum CursorStyle: String, CaseIterable, Identifiable {
    case heart = "Heart"
    case kitty = "Kitty"
    case star = "Star"
    case flower = "Flower"
    case sparkle = "Sparkle"
    case rainbow = "Rainbow"
    case moon = "Moon"
    case sun = "Sun"
    case cloud = "Cloud"
    case butterfly = "Butterfly"
    case bow = "Bow"
    case cherry = "Cherry"
    case cat = "Cat"
    case ghost = "Ghost"
    case rocket = "Rocket"
    case music = "Music"
    case pencil = "Pencil"
    case leaf = "Leaf"
    case donut = "Donut"
    case iceCream = "Ice Cream"

    var id: String { rawValue }

    var number: Int {
        CursorStyle.allCases.firstIndex(of: self)! + 1
    }
}

struct ContentView: View {
    @State private var selectedStyle: CursorStyle = .moon
    @State private var isHovering = false
    @State private var isGlobalEnabled = false
    @State private var accessibilityGranted = AXIsProcessTrusted()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.94, blue: 0.96),
                    Color(red: 0.95, green: 0.98, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Text("Custom Cursor Demo")
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text("Choose a cursor by number, then enable it everywhere.")
                        .foregroundStyle(.secondary)
                }

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(CursorStyle.allCases) { style in
                            Button {
                                selectedStyle = style
                            } label: {
                                VStack(spacing: 3) {
                                    Text("\(style.number)")
                                        .font(.headline)
                                    Text(style.rawValue)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(selectedStyle == style ? .pink : .gray)
                        }
                    }
                }
                .frame(maxWidth: 430, maxHeight: 190)

                Text(accessibilityGranted ? "Accessibility permission: ready" : "Accessibility permission: required")
                    .font(.caption)
                    .foregroundStyle(accessibilityGranted ? .green : .orange)

                Button(isGlobalEnabled ? "Restore normal cursor" : "Show only custom cursor") {
                    isGlobalEnabled.toggle()
                    if isGlobalEnabled {
                        GlobalCursorManager.shared.start(style: selectedStyle)
                    } else {
                        GlobalCursorManager.shared.stop()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isGlobalEnabled ? .red : .green)

                CursorPanel(selectedStyle: selectedStyle, isHovering: $isHovering)
                    .frame(width: 360, height: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                    )

                Text(isHovering ? "Cursor active in app" : "Move pointer over the panel")
                    .font(.headline)
                    .foregroundStyle(isHovering ? .pink : .secondary)
            }
            .padding(32)
        }
        .frame(width: 560, height: 620)
        .onAppear {
            accessibilityGranted = AXIsProcessTrusted()
        }
        .onChange(of: selectedStyle) { style in
            if isGlobalEnabled {
                GlobalCursorManager.shared.update(style: style)
            }
        }
        .onDisappear {
            GlobalCursorManager.shared.stop()
        }
    }
}

private struct CursorPanel: NSViewRepresentable {
    let selectedStyle: CursorStyle
    @Binding var isHovering: Bool

    func makeNSView(context: Context) -> TrackingCursorView {
        let view = TrackingCursorView()
        view.onHoverChange = { hovering in
            isHovering = hovering
        }
        return view
    }

    func updateNSView(_ nsView: TrackingCursorView, context: Context) {
        nsView.cursor = selectedStyle.cursor
    }
}

private final class TrackingCursorView: NSView {
    var cursor: NSCursor = .arrow
    var onHoverChange: ((Bool) -> Void)?
    private var trackingAreaRef: NSTrackingArea?

    override func updateTrackingAreas() {
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        cursor.set()
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        onHoverChange?(false)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: cursor)
    }
}

private final class GlobalCursorManager {
    static let shared = GlobalCursorManager()

    private var overlayWindow: NSWindow?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var isRunning = false

    func start(style: CursorStyle) {
        guard !isRunning else {
            update(style: style)
            return
        }

        _ = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary)

        let mask = (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.rightMouseDragged.rawValue)
            | (1 << CGEventType.otherMouseDragged.rawValue)
        let managerPointer = Unmanaged.passUnretained(self).toOpaque()

        if AXIsProcessTrusted() {
            eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: CGEventMask(mask),
                callback: globalCursorEventTapCallback,
                userInfo: managerPointer
            )

            if let eventTap {
                runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
                if let runLoopSource {
                    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
                }
            }
        }

        let monitorMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: monitorMask) { [weak self] _ in
            DispatchQueue.main.async {
                self?.moveOverlay(to: NSEvent.mouseLocation)
            }
        }

        update(style: style)
        isRunning = true
        NSCursor.hide()
        CGDisplayHideCursor(CGMainDisplayID())
        moveOverlay(to: NSEvent.mouseLocation)

        if eventTap == nil && globalMonitor == nil {
            print("Allow Accessibility access so the custom cursor can follow the pointer outside this app.")
        }
    }

    func update(style: CursorStyle) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
            imageView.image = style.cursorImage
            imageView.imageScaling = .scaleProportionallyUpOrDown

            if let window = overlayWindow {
                window.contentView = imageView
            } else {
                let window = NSWindow(
                    contentRect: imageView.frame,
                    styleMask: .borderless,
                    backing: .buffered,
                    defer: false
                )
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = false
                window.ignoresMouseEvents = true
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.contentView = imageView
                overlayWindow = window
            }
            overlayWindow?.orderFrontRegardless()
        }
    }

    func stop() {
        guard isRunning else { return }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        runLoopSource = nil
        eventTap = nil
        globalMonitor = nil
        isRunning = false
        NSCursor.unhide()
        CGDisplayShowCursor(CGMainDisplayID())
    }

    fileprivate func moveOverlay(to location: NSPoint) {
        overlayWindow?.setFrameOrigin(NSPoint(x: location.x + 1, y: location.y - 31))
    }
}

private func globalCursorEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<GlobalCursorManager>.fromOpaque(userInfo).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.moveOverlay(to: NSEvent.mouseLocation)
    }
    return Unmanaged.passUnretained(event)
}

private extension CursorStyle {
    var cursorImage: NSImage {
        switch self {
        case .heart: return Self.makeHeartImage()
        case .kitty: return Self.makeKittyImage()
        case .star: return Self.makeStarImage()
        case .flower: return Self.makeFlowerImage()
        case .sparkle: return Self.makeSparkleImage()
        case .rainbow: return Self.makeEmojiImage("🌈")
        case .moon: return Self.makeEmojiImage("🌙")
        case .sun: return Self.makeEmojiImage("☀️")
        case .cloud: return Self.makeEmojiImage("☁️")
        case .butterfly: return Self.makeEmojiImage("🦋")
        case .bow: return Self.makeEmojiImage("🎀")
        case .cherry: return Self.makeEmojiImage("🍒")
        case .cat: return Self.makeEmojiImage("🐱")
        case .ghost: return Self.makeEmojiImage("👻")
        case .rocket: return Self.makeEmojiImage("🚀")
        case .music: return Self.makeEmojiImage("🎵")
        case .pencil: return Self.makeEmojiImage("✏️")
        case .leaf: return Self.makeEmojiImage("🍃")
        case .donut: return Self.makeEmojiImage("🍩")
        case .iceCream: return Self.makeEmojiImage("🍦")
        }
    }

    var cursor: NSCursor {
        switch self {
        case .heart:
            return NSCursor(image: Self.makeHeartImage(), hotSpot: NSPoint(x: 10, y: 10))
        case .kitty:
            return NSCursor(image: Self.makeKittyImage(), hotSpot: NSPoint(x: 12, y: 12))
        case .star:
            return NSCursor(image: Self.makeStarImage(), hotSpot: NSPoint(x: 12, y: 12))
        case .flower:
            return NSCursor(image: Self.makeFlowerImage(), hotSpot: NSPoint(x: 12, y: 12))
        case .sparkle:
            return NSCursor(image: Self.makeSparkleImage(), hotSpot: NSPoint(x: 12, y: 12))
        default:
            return NSCursor(image: cursorImage, hotSpot: NSPoint(x: 12, y: 12))
        }
    }

    static func makeEmojiImage(_ emoji: String) -> NSImage {
        let size = NSSize(width: 32, height: 32)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 25),
            .foregroundColor: NSColor.controlTextColor
        ]
        NSString(string: emoji).draw(at: NSPoint(x: 3, y: 2), withAttributes: attributes)
        return image
    }

    static func makeHeartImage() -> NSImage {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let path = NSBezierPath()
        path.move(to: NSPoint(x: 12, y: 3))
        path.curve(to: NSPoint(x: 3, y: 11), controlPoint1: NSPoint(x: 3, y: 4), controlPoint2: NSPoint(x: 3, y: 8))
        path.curve(to: NSPoint(x: 12, y: 21), controlPoint1: NSPoint(x: 3, y: 16), controlPoint2: NSPoint(x: 7, y: 21))
        path.curve(to: NSPoint(x: 21, y: 11), controlPoint1: NSPoint(x: 17, y: 21), controlPoint2: NSPoint(x: 21, y: 16))
        path.curve(to: NSPoint(x: 12, y: 3), controlPoint1: NSPoint(x: 21, y: 8), controlPoint2: NSPoint(x: 21, y: 4))
        path.close()

        NSColor.systemPink.setFill()
        path.fill()
        return image
    }

    static func makeKittyImage() -> NSImage {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let face = NSBezierPath(ovalIn: NSRect(x: 4, y: 5, width: 16, height: 14))
        NSColor.systemPink.setFill()
        face.fill()

        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: 6, y: 16))
        leftEar.line(to: NSPoint(x: 7, y: 22))
        leftEar.line(to: NSPoint(x: 11, y: 17))
        leftEar.close()
        NSColor.systemPink.setFill()
        leftEar.fill()

        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: 18, y: 16))
        rightEar.line(to: NSPoint(x: 17, y: 22))
        rightEar.line(to: NSPoint(x: 13, y: 17))
        rightEar.close()
        NSColor.systemPink.setFill()
        rightEar.fill()

        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 8, y: 11, width: 2, height: 2)).fill()
        NSBezierPath(ovalIn: NSRect(x: 14, y: 11, width: 2, height: 2)).fill()

        let nose = NSBezierPath(ovalIn: NSRect(x: 11.5, y: 9, width: 1.5, height: 1.5))
        NSColor.systemOrange.setFill()
        nose.fill()

        return image
    }

    static func makeStarImage() -> NSImage {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let path = NSBezierPath()
        for index in 0..<10 {
            let angle = CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 5
            let radius: CGFloat = index.isMultiple(of: 2) ? 10 : 4.5
            let point = NSPoint(x: 12 + cos(angle) * radius, y: 12 + sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.line(to: point) }
        }
        path.close()
        NSColor.systemYellow.setFill()
        path.fill()
        NSColor.systemOrange.setStroke()
        path.lineWidth = 1.2
        path.stroke()
        return image
    }

    static func makeFlowerImage() -> NSImage {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 2) {
            let x = 12 + cos(angle) * 5
            let y = 12 + sin(angle) * 5
            NSColor.systemPink.setFill()
            NSBezierPath(ovalIn: NSRect(x: x - 4, y: y - 6, width: 8, height: 12)).fill()
        }
        NSColor.systemYellow.setFill()
        NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 8, height: 8)).fill()
        return image
    }

    static func makeSparkleImage() -> NSImage {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let path = NSBezierPath()
        path.move(to: NSPoint(x: 12, y: 22))
        path.line(to: NSPoint(x: 14, y: 14))
        path.line(to: NSPoint(x: 22, y: 12))
        path.line(to: NSPoint(x: 14, y: 10))
        path.line(to: NSPoint(x: 12, y: 2))
        path.line(to: NSPoint(x: 10, y: 10))
        path.line(to: NSPoint(x: 2, y: 12))
        path.line(to: NSPoint(x: 10, y: 14))
        path.close()
        NSColor.systemBlue.setFill()
        path.fill()
        return image
    }
}
