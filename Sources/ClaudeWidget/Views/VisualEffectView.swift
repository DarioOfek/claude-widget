import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        applyCorner(v)
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blendingMode
        applyCorner(v)
    }

    private func applyCorner(_ v: NSVisualEffectView) {
        guard cornerRadius > 0 else { return }
        v.wantsLayer = true
        v.layer?.cornerRadius = cornerRadius
        v.layer?.masksToBounds = true
    }
}
