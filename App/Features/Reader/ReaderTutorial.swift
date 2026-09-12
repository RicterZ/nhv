import SwiftUI

struct ReaderTutorial: View {
    var pageTurnMode = PageTurnMode.tap
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            ScrollView {
                VStack(spacing: 28) {
                    Text("Reading controls")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)

                    Group {
                        if pageTurnMode.isContinuous {
                            VStack(spacing: 16) {
                                pageHint(title: "Continuous Scroll", caption: "Scroll up or down",
                                    icon: "hand.draw", arrow: "arrow.up.and.down")
                                Rectangle()
                                    .fill(.white.opacity(0.25))
                                    .frame(maxWidth: 280)
                                    .frame(height: 1)
                                    .accessibilityHidden(true)
                                pageHint(title: "Close reader", caption: "Swipe right",
                                    icon: "hand.draw", arrow: "arrow.right")
                            }
                        } else if pageTurnMode.scrollsVertically {
                            VStack(spacing: 16) {
                                pageHint(title: "Previous page", caption: "Swipe down",
                                    icon: "hand.draw", arrow: "arrow.down")
                                Rectangle()
                                    .fill(.white.opacity(0.25))
                                    .frame(maxWidth: 280)
                                    .frame(height: 1)
                                    .accessibilityHidden(true)
                                pageHint(title: "Next page", caption: "Swipe up",
                                    icon: "hand.draw", arrow: "arrow.up")
                                Rectangle()
                                    .fill(.white.opacity(0.25))
                                    .frame(maxWidth: 280)
                                    .frame(height: 1)
                                    .accessibilityHidden(true)
                                pageHint(title: "Close reader", caption: "Swipe right",
                                    icon: "hand.draw", arrow: "arrow.right")
                            }
                        } else {
                            HStack(alignment: .top, spacing: 0) {
                                pageHint(title: "Previous page", caption: pageTurnMode == .tap ? "Tap the left half" : "Swipe right",
                                    icon: pageTurnMode == .tap ? "hand.point.up.left" : "hand.draw", arrow: pageTurnMode == .tap ? "arrow.left" : "arrow.right")
                                Rectangle()
                                    .fill(.white.opacity(0.25))
                                    .frame(width: 1, height: 120)
                                    .accessibilityHidden(true)
                                pageHint(title: "Next page", caption: pageTurnMode == .tap ? "Tap the right half" : "Swipe left",
                                    icon: pageTurnMode == .tap ? "hand.point.up.left" : "hand.draw", arrow: pageTurnMode == .tap ? "arrow.right" : "arrow.left")
                            }
                        }
                    }
                    .padding(.vertical, 12)

                    VStack(spacing: 16) {
                        Label("Pinch with two fingers to zoom", systemImage: "arrow.up.left.and.arrow.down.right")
                        Label("When zoomed in, drag to move the image", systemImage: "hand.draw")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: 440, alignment: .leading)

                    Button(action: dismiss) {
                        Text("Got it")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(.black)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: 320)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.center)
            .scrollBounceBehavior(.basedOnSize)
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func pageHint(title: LocalizedStringKey, caption: LocalizedStringKey, icon: String, arrow: String) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: arrow)
                Image(systemName: icon)
            }
            .font(.title)
            .accessibilityHidden(true)
            Text(title).font(.headline)
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    }
}
