import SwiftUI

/// Holy See orientation: grips below, the teeth of both crossed keys facing outward.
/// Shared by the Apple app (including Mac) and its Today widget.
struct PapalKeysSymbol: View {
  var size: CGFloat = 24

  var body: some View {
    ZStack {
      PapalKeyShape().stroke(style: StrokeStyle(lineWidth: size * 1.8 / 24, lineCap: .round, lineJoin: .round))
      PapalKeyShape().stroke(style: StrokeStyle(lineWidth: size * 1.8 / 24, lineCap: .round, lineJoin: .round))
        .scaleEffect(x: -1, y: 1)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

private struct PapalKeyShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addEllipse(in: CGRect(x: 2, y: 16, width: 6, height: 6))
    path.move(to: CGPoint(x: 7, y: 17))
    path.addLine(to: CGPoint(x: 20, y: 4))
    path.move(to: CGPoint(x: 19, y: 5))
    path.addLine(to: CGPoint(x: 22, y: 8))
    path.move(to: CGPoint(x: 16, y: 8))
    path.addLine(to: CGPoint(x: 19, y: 11))
    return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
  }
}
