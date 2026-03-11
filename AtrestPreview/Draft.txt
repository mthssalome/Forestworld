import SwiftUI

struct MasterSceneLab: View {

    @EnvironmentObject private var store: SceneStore

    // MARK: - Preview/Debug State
    @State private var scrollOffset: CGFloat = 0.0
    @State private var growthProgress: Double = 0.65
    @State private var showDebugOverlay: Bool = false

    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            let viewport = geo.size

            ZStack(alignment: .topLeading) {

                // 1. Scene layers
                TimelineView(.animation) { timeline in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    sceneStack(viewport: viewport, time: now)
                }

                // 2. Scroll gesture
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let raw = value.translation.width / viewport.width
                                let clamped = max(
                                    -contract.interactivity.scroll_response.max_offset_limit,
                                    min(
                                        contract.interactivity.scroll_response.max_offset_limit,
                                        CGFloat(raw)
                                    )
                                )
                                scrollOffset = clamped * CGFloat(contract.interactivity.scroll_response.velocity_multiplier)
                            }
                            .onEnded { _ in
                                scrollOffset = 0.0
                            }
                    )

                // 3. Debug overlay
                #if DEBUG
                if showDebugOverlay {
                    debugOverlay(viewport: viewport)
                }
                #endif
            }
            .ignoresSafeArea()
            .onAppear {
                if let tp = store.treePathsRegistry {
                    TreeAssetRegistry.configure(with: tp)
                } else {
                    fatalError("MasterSceneLab: TreePathsRegistry not loaded in SceneStore")
                }
            }
        }
    }

    // MARK: - Scene Stack
@ViewBuilder
private func sceneStack(viewport: CGSize, time: Double) -> some View {

    if store.contract == nil {
        // Store not ready yet — blank frame
        Color.black
            .ignoresSafeArea()
    } else {
        ZStack {
            ForEach(Array(store.orderedSystems.enumerated()), id: \.offset) { _, system in
                RenderLayer(
                    system: system,
                    contract: contract,
                    scrollOffset: scrollOffset,
                    time: time,
                    viewport: viewport,
                    growthProgress: growthProgress
                )
            }
        }
        .frame(width: viewport.width, height: viewport.height)
    }
}


    // MARK: - Debug Overlay
    @ViewBuilder
    private func debugOverlay(viewport: CGSize) -> some View {
        let horizonY  = contract.spatial_framework.global_horizon_y
        let immersionY = contract.spatial_framework.immersion_floor_y

        ZStack(alignment: .topLeading) {

            Rectangle()
                .fill(Color.cyan.opacity(0.6))
                .frame(width: viewport.width, height: 1)
                .offset(y: horizonY * viewport.height)

            Rectangle()
                .fill(Color.orange.opacity(0.6))
                .frame(width: viewport.width, height: 1)
                .offset(y: immersionY * viewport.height)

            VStack(spacing: 4) {
                Text("HORIZON y=\(String(format: "%.2f", horizonY))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.cyan)
                    .offset(y: horizonY * viewport.height)

                Text("IMMERSION y=\(String(format: "%.2f", immersionY))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.orange)
                    .offset(y: immersionY * viewport.height)
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Contract Convenience
    private var contract: GlobalSceneContract {
        guard let c = store.contract else {
            fatalError("MasterSceneLab: GlobalSceneContract not loaded")
        }
        return c
    }
}

// MARK: - Preview
#Preview {
    MasterSceneLab()
        .environmentObject(SceneStore())
}
