import AppKit
import SwiftUI

let args = CommandLine.arguments
let title = args[1]
let lines = args[2].split(separator: "\n", maxSplits: 1).map(String.init)
let seconds = Double(args[3])!
let reconnect = args.count > 4 && args[4] == "reconnect"
let status = lines[0]
let commit = lines.count > 1 ? lines[1] : nil

func hex(_ value: UInt32) -> Color {
    Color(red: Double(value >> 16 & 0xff) / 255, green: Double(value >> 8 & 0xff) / 255, blue: Double(value & 0xff) / 255)
}

// The dark palette of the Anatomy figures: https://skills.wheresryan.sh/anatomy
enum Tone {
    static let card = hex(0x131313)
    static let top = hex(0x1c1c1c)
    static let shades = [hex(0x0f0f0f), hex(0x121212), hex(0x151515), hex(0x181818)]
    static let litTop = hex(0x262626)
    static let litShades = [hex(0x161616), hex(0x191919), hex(0x1d1d1d), hex(0x212121)]
    static let hi = hex(0xd4d4d4)
    static let mid = hex(0x6a6a6a)
    static let lo = hex(0x3e3e3e)
    static let faint = hex(0x2a2a2a)
    static let dot = hex(0xe6e6e6)
    static let green = hex(0x6be0a0)
    static let gold = hex(0xdbab45)
    static let text = hex(0xe6e6e6)
    static let muted = hex(0xa3a3a3)
}

enum Iso {
    static func top(_ z: CGFloat) -> CGAffineTransform {
        CGAffineTransform(a: 0.866, b: -0.5, c: 0.866, d: 0.5, tx: 0, ty: -z)
    }

    static func side(_ x: CGFloat) -> CGAffineTransform {
        CGAffineTransform(a: 0.866, b: 0.5, c: 0, d: -1, tx: x * 0.866, ty: x * -0.5)
    }

    static func shift(_ x: CGFloat) -> CGAffineTransform {
        CGAffineTransform(translationX: x * 0.866, y: x * -0.5)
    }

    static func point(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint {
        CGPoint(x: x * 0.866 + y * 0.866, y: x * -0.5 + y * 0.5 - z)
    }
}

func loops(_ path: Path) -> [[CGPoint]] {
    var result: [[CGPoint]] = []
    var current: [CGPoint] = []
    func finish() {
        if let first = current.first, let last = current.last, first == last { current.removeLast() }
        if current.count > 2 { result.append(current) }
        current = []
    }
    func add(_ point: CGPoint) {
        if let last = current.last, hypot(point.x - last.x, point.y - last.y) < 0.01 { return }
        current.append(point)
    }
    path.forEach { element in
        let last = current.last ?? .zero
        switch element {
        case .move(let to):
            finish()
            current = [to]
        case .line(let to):
            add(to)
        case .quadCurve(let to, let control):
            for step in 1...8 {
                let t = CGFloat(step) / 8, u = 1 - t
                add(CGPoint(
                    x: u * u * last.x + 2 * u * t * control.x + t * t * to.x,
                    y: u * u * last.y + 2 * u * t * control.y + t * t * to.y
                ))
            }
        case .curve(let to, let control1, let control2):
            for step in 1...8 {
                let t = CGFloat(step) / 8, u = 1 - t
                add(CGPoint(
                    x: u * u * u * last.x + 3 * u * u * t * control1.x + 3 * u * t * t * control2.x + t * t * t * to.x,
                    y: u * u * u * last.y + 3 * u * u * t * control1.y + 3 * u * t * t * control2.y + t * t * t * to.y
                ))
            }
        case .closeSubpath:
            finish()
        }
    }
    finish()
    return result
}

func area(_ loop: [CGPoint]) -> CGFloat {
    zip(loop, loop.dropFirst() + loop.prefix(1)).reduce(0) { $0 + $1.0.x * $1.1.y - $1.1.x * $1.0.y } / 2
}

struct Wall {
    var a: CGPoint
    var b: CGPoint
    var normal: CGVector
    var visible: Bool
}

func drawPrism(
    _ context: GraphicsContext, face: Path, from z0: CGFloat, to z1: CGFloat, place: CGAffineTransform,
    top: Color, shades: [Color], line: Color, weight: CGFloat
) {
    let view = CGVector(dx: -0.7071, dy: 0.7071)
    let light = CGVector(dx: -0.9, dy: 0.436)
    func project(_ p: CGPoint, _ z: CGFloat) -> CGPoint { p.applying(Iso.top(z)).applying(place) }

    let all = loops(face)
    let outer = all.indices.max { abs(area(all[$0])) < abs(area(all[$1])) }
    var walls: [[Wall]] = []
    for (index, loop) in all.enumerated() {
        let outward: CGFloat = (area(loop) > 0) == (index == outer) ? -1 : 1
        walls.append(loop.indices.map { i in
            let a = loop[i], b = loop[(i + 1) % loop.count]
            let length = max(hypot(b.x - a.x, b.y - a.y), 0.0001)
            let normal = CGVector(dx: -(b.y - a.y) / length * outward, dy: (b.x - a.x) / length * outward)
            return Wall(a: a, b: b, normal: normal, visible: normal.dx * view.dx + normal.dy * view.dy > 0.01)
        })
    }

    let ordered = walls.joined().filter(\.visible).sorted {
        ($0.a.x + $0.b.x) * view.dx + ($0.a.y + $0.b.y) * view.dy < ($1.a.x + $1.b.x) * view.dx + ($1.a.y + $1.b.y) * view.dy
    }
    for wall in ordered {
        let facing = wall.normal.dx * light.dx + wall.normal.dy * light.dy
        let shade = shades[min(max(Int((facing + 1) / 2 * 4), 0), 3)]
        let quad = Path { path in
            path.addLines([project(wall.a, z0), project(wall.b, z0), project(wall.b, z1), project(wall.a, z1)])
            path.closeSubpath()
        }
        context.fill(quad, with: .color(shade))
        context.stroke(quad, with: .color(shade), lineWidth: 0.6)
    }

    let edges = Path { path in
        for loop in walls {
            for (i, wall) in loop.enumerated() {
                let next = loop[(i + 1) % loop.count]
                if wall.visible {
                    path.move(to: project(wall.a, z0))
                    path.addLine(to: project(wall.b, z0))
                }
                let turn = wall.normal.dx * next.normal.dx + wall.normal.dy * next.normal.dy
                if wall.visible != next.visible || (wall.visible && turn < 0.85) {
                    path.move(to: project(wall.b, z0))
                    path.addLine(to: project(wall.b, z1))
                }
            }
        }
    }
    context.stroke(edges, with: .color(line), lineWidth: weight)
    let lid = face.applying(Iso.top(z1)).applying(place)
    context.fill(lid, with: .color(top), style: FillStyle(eoFill: true))
    context.stroke(lid, with: .color(line), lineWidth: weight)
}

struct Figure {
    static let bodyLength: CGFloat = 140
    static let plugLength: CGFloat = 28
    static let plugWidth: CGFloat = 34
    static let travel = plugLength + 30
    static let port = bodyLength + plugLength + 30
    static let thickness: CGFloat = 12
    static let width: CGFloat = 600
    static let bottom: CGFloat = -12
    static let top: CGFloat = 24
    static let contact = CGPoint(x: bodyLength / 2 + 14, y: 0)

    let bodyFace: Path = {
        var path = UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 30, bottomTrailingRadius: 6, topTrailingRadius: 6)
            .path(in: CGRect(x: 0, y: -36, width: bodyLength, height: 72))
        path.addEllipse(in: CGRect(x: 13, y: -8, width: 16, height: 16))
        return path
    }()
    let base = Path(roundedRect: CGRect(x: port, y: -139, width: width, height: 420), cornerRadius: 30)
    let lidSolid: Path
    let lidFace: Path
    let display: Path
    let well: Path
    let keys: Path
    let grille: Path
    let portFace: Path
    let otherPorts: Path
    let portDetails: Path
    let bounds: CGRect

    init() {
        let port = Self.port, width = Self.width, top = Self.top
        let (back, up): (CGFloat, CGFloat) = (0.342, 0.94)
        let hinge = Iso.point(port, -129, top - 4)
        let lidPlane = CGAffineTransform(
            a: 0.866, b: -0.5, c: -back * 0.866, d: -back * 0.5 - up, tx: hinge.x, ty: hinge.y
        )
        lidFace = UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 18, bottomTrailingRadius: 18, topTrailingRadius: 4)
            .path(in: CGRect(x: 2, y: 0, width: width - 4, height: 400))
            .applying(lidPlane)
        let face = lidFace
        lidSolid = stride(from: 0, through: 6, by: 1).reduce(Path()) { solid, depth in
            let behind = Iso.point(0, -up * depth, -back * depth)
            return solid.union(face.applying(CGAffineTransform(translationX: behind.x, y: behind.y)))
        }
        display = Path(roundedRect: CGRect(x: 16, y: 14, width: width - 32, height: 372), cornerRadius: 10).applying(lidPlane)

        let unit: CGFloat = 36
        let rows: [(height: CGFloat, widths: [CGFloat])] = [
            (18, [1.5] + Array(repeating: 1, count: 13)),
            (32, Array(repeating: 1, count: 13) + [1.5]),
            (32, [1.5] + Array(repeating: 1, count: 13)),
            (32, [1.8] + Array(repeating: 1, count: 11) + [1.75]),
            (32, [2.3] + Array(repeating: 1, count: 10) + [2.3]),
            (32, [1, 1, 1, 1.25, 5, 1.25, 1, 1, 1, 1]),
        ]
        var rects: [CGRect] = []
        var y: CGFloat = -104
        for row in rows {
            var x = port + 50
            for units in row.widths {
                rects.append(CGRect(x: x, y: y, width: units * unit - 4, height: row.height))
                x += units * unit
            }
            y += row.height + 4
        }
        let keyboard = rects.reduce(CGRect.null) { $0.union($1) }.insetBy(dx: -5, dy: -5)
        well = Path(roundedRect: keyboard, cornerRadius: 8).applying(Iso.top(top))
        keys = Path { path in
            for rect in rects {
                path.addRoundedRect(in: rect, cornerSize: CGSize(width: 3, height: 3))
            }
        }.applying(Iso.top(top))
        grille = Path { path in
            for row in 0..<34 {
                for column in 0..<4 {
                    path.addEllipse(in: CGRect(x: port + 14 + CGFloat(column) * 7, y: keyboard.minY + 4 + CGFloat(row) * 6, width: 2, height: 2))
                }
            }
        }.applying(Iso.top(top))

        let side = Iso.side(port)
        let center = Self.thickness / 2
        portFace = Path(roundedRect: CGRect(x: -19, y: center - 6, width: 38, height: 12), cornerRadius: 6).applying(side)
        var others = Path()
        others.addPath(Path(roundedRect: CGRect(x: -83, y: center - 5, width: 56, height: 10), cornerRadius: 5).applying(side))
        others.addPath(Path(roundedRect: CGRect(x: 26, y: center - 6, width: 38, height: 12), cornerRadius: 6).applying(side))
        others.addPath(Path(ellipseIn: CGRect(x: 116, y: center - 6.5, width: 13, height: 13)).applying(side))
        otherPorts = others
        portDetails = Path { path in
            for port in [0, 45] as [CGFloat] {
                path.addRoundedRect(in: CGRect(x: port - 11, y: center - 1.5, width: 22, height: 3), cornerSize: CGSize(width: 1.5, height: 1.5))
            }
            path.addRoundedRect(in: CGRect(x: -80, y: center - 3, width: 50, height: 6), cornerSize: CGSize(width: 3, height: 3))
            for pin in 0..<5 {
                path.addEllipse(in: CGRect(x: -64 + CGFloat(pin) * 4.5, y: center - 1, width: 2, height: 2))
            }
            path.addEllipse(in: CGRect(x: 119.5, y: center - 3, width: 6, height: 6))
        }.applying(side)

        let key = bodyFace.applying(Iso.top(Self.thickness)).boundingRect
            .union(bodyFace.applying(Iso.top(0)).boundingRect)
        bounds = [Iso.point(port, -110, top + 90), Iso.point(port, 170, Self.bottom), Iso.point(port + 140, -110, top)]
            .reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
            .union(key)
            .union(key.applying(Iso.shift(Self.travel)))
    }

    func fit(_ size: CGSize) -> CGAffineTransform {
        let scale = min(size.width / bounds.width, size.height / bounds.height)
        return CGAffineTransform(translationX: -bounds.midX, y: -bounds.midY)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: size.width / 2, y: size.height / 2))
    }

    func draw(_ context: GraphicsContext, size: CGSize, x: CGFloat, lit: Double, ring: Double = 0) {
        let fit = fit(size)

        context.fill(lidSolid.applying(fit), with: .color(Tone.shades[0]))
        context.stroke(lidSolid.applying(fit), with: .color(Tone.lo), lineWidth: 0.8)
        context.fill(lidFace.applying(fit), with: .color(Tone.shades[2]))
        context.stroke(lidFace.applying(fit), with: .color(Tone.mid), lineWidth: 0.8)
        context.fill(display.applying(fit), with: .color(Tone.shades[0]))
        context.stroke(display.applying(fit), with: .color(Tone.faint), lineWidth: 0.8)

        drawPrism(context, face: base, from: Self.bottom, to: Self.top, place: fit, top: Tone.top, shades: Tone.shades, line: Tone.mid, weight: 0.8)
        context.fill(well.applying(fit), with: .color(Tone.shades[0]))
        context.stroke(well.applying(fit), with: .color(Tone.faint), lineWidth: 0.8)
        context.fill(keys.applying(fit), with: .color(Tone.top))
        context.stroke(keys.applying(fit), with: .color(Tone.lo), lineWidth: 0.6)
        context.fill(grille.applying(fit), with: .color(Tone.dot.opacity(0.25)))
        context.fill(otherPorts.applying(fit), with: .color(Tone.shades[0]))
        context.stroke(otherPorts.applying(fit), with: .color(Tone.mid), lineWidth: 0.8)
        context.fill(portFace.applying(fit), with: .color(Tone.shades[0]))
        context.stroke(portFace.applying(fit), with: .color(Tone.hi), lineWidth: 0.8)
        context.stroke(portDetails.applying(fit), with: .color(Tone.lo), lineWidth: 0.6)

        let place = Iso.shift(x).concatenating(fit)
        let visible = min(Self.plugLength, Self.port - x - Self.bodyLength)
        if visible > 0.5 {
            let rect = CGRect(x: Self.bodyLength, y: -Self.plugWidth / 2, width: visible, height: Self.plugWidth)
            let plug = visible < Self.plugLength
                ? Path(rect)
                : UnevenRoundedRectangle(bottomTrailingRadius: 4, topTrailingRadius: 4).path(in: rect)
            drawPrism(context, face: plug, from: 1, to: 11, place: place, top: Tone.litTop, shades: Tone.litShades, line: Tone.hi, weight: 1)
        }
        drawPrism(context, face: bodyFace, from: 0, to: Self.thickness, place: place, top: Tone.litTop, shades: Tone.litShades, line: Tone.hi, weight: 1)

        func spot(_ radius: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: Self.contact.x - radius, y: -radius, width: radius * 2, height: radius * 2))
                .applying(Iso.top(Self.thickness)).applying(place)
        }
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Tone.green.opacity(lit), radius: 14))
            layer.fill(spot(20), with: .color(Tone.green.opacity(lit * 0.85)))
        }
        context.stroke(spot(20), with: .color(Tone.gold), lineWidth: 1.5)
        if ring > 0 {
            let fade = min(ring / 0.15, 1) * (1 - ring)
            context.stroke(spot(20 * (1 + 1.4 * ring)), with: .color(Tone.green.opacity(0.85 * fade)), lineWidth: 1.5)
        }
    }
}

extension View {
    func figureFade() -> some View {
        frame(width: 440, height: 220)
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.25)], startPoint: .top, endPoint: .bottom))
            .mask(LinearGradient(stops: [.init(color: .black, location: 0.6), .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing))
    }
}

struct Pulse {
    var lit = 0.0
    var ring = 0.0
}

struct TouchAnimation: View {
    let figure = Figure()

    var body: some View {
        KeyframeAnimator(initialValue: Pulse(), repeating: true) { pulse in
            Canvas { context, size in
                figure.draw(context, size: size, x: Figure.travel, lit: pulse.lit, ring: pulse.ring)
            }
        } keyframes: { _ in
            KeyframeTrack(\.lit) {
                LinearKeyframe(1, duration: 0.3, timingCurve: .easeInOut)
                LinearKeyframe(0, duration: 1.1, timingCurve: .easeInOut)
            }
            KeyframeTrack(\.ring) {
                LinearKeyframe(1, duration: 1.4, timingCurve: .easeOut)
            }
        }
        .figureFade()
    }
}

struct Plug {
    var x = 0.0
    var lit = 0.0
}

struct ReconnectAnimation: View {
    let figure = Figure()

    var body: some View {
        KeyframeAnimator(initialValue: Plug(), repeating: true) { plug in
            Canvas { context, size in
                figure.draw(context, size: size, x: plug.x, lit: plug.lit)
            }
        } keyframes: { _ in
            KeyframeTrack(\.x) {
                LinearKeyframe(0, duration: 0.4)
                LinearKeyframe(Figure.travel, duration: 0.9, timingCurve: .easeInOut)
                LinearKeyframe(Figure.travel, duration: 0.9)
                LinearKeyframe(0, duration: 0.9, timingCurve: .easeInOut)
            }
            KeyframeTrack(\.lit) {
                LinearKeyframe(0, duration: 1.3)
                LinearKeyframe(1, duration: 0.25, timingCurve: .easeInOut)
                LinearKeyframe(1, duration: 0.4)
                LinearKeyframe(0, duration: 0.25, timingCurve: .easeInOut)
                LinearKeyframe(0, duration: 0.9)
            }
        }
        .figureFade()
    }
}

struct Card: View {
    var body: some View {
        VStack(spacing: 18) {
            if reconnect {
                ReconnectAnimation()
            } else {
                TouchAnimation()
            }
            Text(title)
                .font(.system(size: 40, weight: .semibold))
                .tracking(-0.6)
                .foregroundStyle(Tone.text)
            Text(status)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Tone.mid)
            if let commit {
                Text(commit)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Tone.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Tone.shades[2], in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Tone.faint))
                    .frame(maxWidth: 520)
            }
        }
        .padding(.horizontal, 64)
        .padding(.vertical, 44)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Tone.card)
                .shadow(color: .black.opacity(0.35), radius: 40, y: 16)
        }
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Tone.faint))
    }
}

struct Prompt: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
            Card()
        }
        .environment(\.colorScheme, .dark)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let panels = NSScreen.screens.map { screen in
    let panel = NSPanel(
        contentRect: screen.frame,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.level = .screenSaver
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    panel.contentView = NSHostingView(rootView: Prompt())
    panel.setFrame(screen.frame, display: true)
    panel.alphaValue = 0
    panel.orderFrontRegardless()
    return panel
}
NSAnimationContext.runAnimationGroup { context in
    context.duration = 0.25
    panels.forEach { $0.animator().alphaValue = 1 }
}

signal(SIGTERM, SIG_IGN)
let term = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
term.setEventHandler { app.terminate(nil) }
term.resume()

DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { app.terminate(nil) }
app.run()
