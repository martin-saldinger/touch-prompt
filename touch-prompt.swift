import AppKit
import SwiftUI

let args = CommandLine.arguments
let title = args.count > 1 ? args[1] : "Touch your YubiKey"
let subtitle = args.count > 2 ? args[2] : "git is waiting for a signature"
let seconds = args.count > 3 ? Double(args[3]) ?? 30 : 30

struct Ripple {
    var scale = 1.0
    var opacity = 0.0
}

struct Prompt: View {
    @State private var breathe = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 140, height: 140)
                        .scaleEffect(breathe ? 1.15 : 0.9)
                    Circle()
                        .strokeBorder(Color.green.opacity(0.5), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .keyframeAnimator(initialValue: Ripple(), repeating: true) { ring, ripple in
                            ring.scaleEffect(ripple.scale).opacity(ripple.opacity)
                        } keyframes: { _ in
                            KeyframeTrack(\.scale) {
                                CubicKeyframe(1.5, duration: 1.4)
                            }
                            KeyframeTrack(\.opacity) {
                                CubicKeyframe(1, duration: 0.3)
                                CubicKeyframe(0, duration: 1.1)
                            }
                        }
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 60, weight: .semibold))
                        .foregroundStyle(.green)
                        .symbolEffect(.pulse, options: .repeating)
                }
                .frame(height: 200)
                Text(title)
                    .font(.system(size: 44, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 72)
            .padding(.vertical, 48)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).strokeBorder(.white.opacity(0.12)))
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { breathe = true }
        }
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
