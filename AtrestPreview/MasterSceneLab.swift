// MasterSceneLab.swift
// Orchestrates the full Atrest scene.
// Loads contract → systems → sorts by depth → renders via TimelineView.
// Provides debug overlay (horizon + immersion floor lines).
// This view only orchestrates — it never renders visual elements directly.

import SwiftUI

struct MasterSceneLab: View {

    @EnvironmentObject private var store: SceneStore

    // MARK: - Preview/Debug State

    @State private var scrollOffset: CGFloat = 0.0
    @State private var growthProgress: Double = 0.65  // Non-zero for preview visibility
    @State private var showDebugOverlay: Bool = false

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let viewport = geo.size

            ZStack(alignment: .topLeading) {
                // 1. Scene layers — rendered in contract depth order via TimelineView
                TimelineView(.animation) { timeline in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    sceneStack(viewport: viewport, time: now)
                }

                // 2. Scroll gesture — modulates parallax input
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let raw = value.translation.width / viewport.width
                                let clamped = max(
                                    -contract.interactivity.scroll_response.max_offset_limit,
                                    min(contract.interactivity.scroll_response.max_offset_limit,
                                        CGFloat(raw))
                                )
                                scrollOffset = clamped * CGFloat(contract.interactivity.scroll_response.velocity_multiplier)
                            }
                            .onEnded { _ in
                                scrollOffset = 0.0
                            }
                    )

                // 3. Debug overlay (development only)
                #if DEBUG
                if showDebugOverlay {
                    debugOverlay(viewport: viewport)
                }
                #endif
            }
            .frame(width: viewport.width, height: viewport.height)
            .ignoresSafeArea()
            .onAppear {
                // Configure TreeAssetRegistry with loaded data
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
        guard let _ = store.contract else {
            // Store not ready yet — blank frame
            Color.black.ignoresSafeArea()
            return
        }

        ZStack {
            // Iterate in depth order (SceneStore already sorts by depth_ordering_bands)
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

    // MARK: - Debug Overlay

    @ViewBuilder
    private func debugOverlay(viewport: CGSize) -> some View {
        let horizonY  = contract.spatial_framework.global_horizon_y
        let immersionY = contract.spatial_framework.immersion_floor_y

        // Horizon line
        Rectangle()
            .fill(Color.cyan.opacity(0.6))
            .frame(width: viewport.width, height: 1)
            .offset(y: horizonY * viewport.height)

        // Immersion floor line
        Rectangle()
            .fill(Color.orange.opacity(0.6))
            .frame(width: viewport.width, height: 1)
            .offset(y: immersionY * viewport.height)

        // Labels
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
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
