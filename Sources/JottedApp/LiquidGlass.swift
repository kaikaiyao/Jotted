import AppKit
import SwiftUI

/// Liquid Glass adoption layer.
///
/// The project still deploys to macOS 14, and it may be compiled by an Xcode
/// that predates the macOS 26 SDK, so every call into the new API is guarded
/// twice: `#if compiler(>=6.2)` keeps the symbols out of older compilers, and
/// `#available(macOS 26.0, *)` keeps them out of older systems at runtime.
///
/// Liquid Glass is applied to *floating* elements only — toasts, chips,
/// buttons, cards. The board panel itself keeps `NSVisualEffectView` with
/// `behindWindow` blending, which is the supported way for a borderless panel
/// to sample the desktop underneath it.
enum JottedGlass {
    /// True when the running system can render real Liquid Glass.
    static var isSupported: Bool {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            return true
        }
        #endif
        return false
    }

    /// Liquid Glass is a compositor effect and does not appear in the bitmaps
    /// produced by `cacheDisplay(in:to:)`, so the README snapshot pipeline
    /// rendered blank panels. Snapshot runs opt back into the legacy surface,
    /// which does draw into an offscreen bitmap.
    nonisolated(unsafe) static var forcesLegacySurface = false
}

#if compiler(>=6.2)
@available(macOS 26.0, *)
private func jottedGlassStyle(tint: Color?, interactive: Bool) -> Glass {
    var glass = Glass.regular
    if let tint {
        glass = glass.tint(tint)
    }
    if interactive {
        glass = glass.interactive()
    }
    return glass
}
#endif

extension View {
    /// Applies Liquid Glass on macOS 26, or a hand-built glass background on
    /// earlier systems.
    ///
    /// - Parameters:
    ///   - shape: the shape the glass is clipped to.
    ///   - tint: theme signature color, already at its intended opacity.
    ///   - interactive: opt into the pressed/hover glass response.
    ///   - fallback: the pre-26 background, built only when needed.
    @ViewBuilder
    func jottedGlass<S: Shape, F: View>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false,
        @ViewBuilder fallback: () -> F
    ) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            if JottedGlass.forcesLegacySurface {
                self.background { fallback() }
            } else {
                self.glassEffect(
                    jottedGlassStyle(tint: tint, interactive: interactive),
                    in: shape
                )
            }
        } else {
            self.background { fallback() }
        }
        #else
        self.background { fallback() }
        #endif
    }
}

/// The pre-macOS 26 glass surface: a within-window vibrancy material, a theme
/// tint, and a single specular edge. Cheap enough to place on floating chrome
/// without an offscreen pass.
struct LegacyGlassSurface<S: InsettableShape>: View {
    let shape: S
    var tint: Color?
    var material: NSVisualEffectView.Material = .popover

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VisualEffectView(material: material, blendingMode: .withinWindow)
            .overlay {
                if let tint {
                    tint
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color.white.opacity(0.22), Color.white.opacity(0.05)]
                            : [Color.white.opacity(0.92), Color.white.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
            }
    }
}
