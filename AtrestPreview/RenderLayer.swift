// RenderLayer.swift
// Single layer executor: applies contract parallax + camera drift,
// then routes to the correct system view.
// No visual constants. No cross-system reads.

import SwiftUI

struct RenderLayer: View {

    let system: LoadedSystem
    let contract: GlobalSceneContract
    let scrollOffset: CGFloat
    let time: Double
    let viewport: CGSize
    let growthProgress: Double

    @EnvironmentObject private var store: SceneStore

    var body: some View {
        let spec = system.spec
        let baseFactor = contract.parallax_bands[spec.references.parallax_id] ?? {
            fatalError("RenderLayer: parallax_id '\(spec.references.parallax_id)' not in contract.parallax_bands")
        }()

        let policy: GlobalSceneContract.SpatialFramework.ParallaxVectorPolicy = {
            if let overrides = contract.spatial_framework.parallax_vector_overrides,
               let override = overrides[spec.references.layer_id] {
                return override
            }
            return contract.spatial_framework.parallax_vector_policy
        }()

        // ParallaxVec_Inv_01: 0.0 <= y_multiplier <= 0.25
        let yMult = policy.y_multiplier
        precondition(yMult >= 0.0 && yMult <= 0.25,
                     "RenderLayer: y_multiplier \(yMult) violates ParallaxVec_Inv_01")

        // Camera drift from contract interactivity profile
        let drift = contract.interactivity.camera_drift
        let attenuation = computeDriftAttenuation(growthProgress: growthProgress,
                                                  attenuation: contract.interactivity.rest_state_attenuation)
        let dx = sin(2.0 * .pi * drift.frequency_hz * time) * drift.amplitude_x * attenuation
        let dy = cos(2.0 * .pi * drift.frequency_hz * time) * drift.amplitude_y * attenuation

        // Total parallax offset
        let totalX = (Double(scrollOffset) + dx) * baseFactor * policy.x_multiplier
        let totalY = (Double(scrollOffset) + dy) * baseFactor * yMult

        return Group {
            routeToView(spec: spec)
        }
        .offset(x: totalX * viewport.width, y: totalY * viewport.height)
    }

    // MARK: - View Router

    @ViewBuilder
    private func routeToView(spec: SystemSpec) -> some View {
        switch spec.references.layer_id {
        case "sky":
            SkyView(system: system, contract: contract, viewport: viewport)
        case "stars":
            StarsView(layerId: "stars", store: store, contract: contract, time: time)
        case "ground_plate":
            GroundPlateView(system: system, contract: contract, viewport: viewport)
        case "arrival_hero":
            ArrivalTreeView(system: system, contract: contract,
                            growthProgress: growthProgress, viewport: viewport)
        default:
            // Forest layers, mountains, fog
            ForestLayerView(system: system, contract: contract, viewport: viewport)
        }
    }

    // MARK: - Rest-State Attenuation (Contract v7)

    private func computeDriftAttenuation(
        growthProgress: Double,
        attenuation: GlobalSceneContract.Interactivity.RestStateAttenuation
    ) -> Double {
        let hinge = attenuation.progress_hinge
        let mMin  = attenuation.drift_multiplier_at_zero
        if growthProgress < hinge {
            return mMin + (1.0 - mMin) * (growthProgress / hinge)
        }
        return 1.0
    }
}

// MARK: - Sky View

struct SkyView: View {
    let system: LoadedSystem
    let contract: GlobalSceneContract
    let viewport: CGSize

    var body: some View {
        guard let skySpec = try? JSONDecoder().decode(SkySystemSpec.self, from: system.rawData) else {
            fatalError("SkyView: Failed to decode SkySystemSpec")
        }

        let stops = skySpec.gradient_stops.map { stop -> Gradient.Stop in
            let color = Color(cgColor: .fromHex(stop.hex))
            return Gradient.Stop(color: color, location: stop.offset)
        }

        // Sky_Inv_01: last stop offset == global_horizon_y
        let lastOffset = skySpec.gradient_stops.last?.offset ?? 0
        precondition(abs(lastOffset - contract.spatial_framework.global_horizon_y) < 1e-6,
                     "SkyView: Sky_Inv_01 violated — last gradient stop offset != global_horizon_y")

        return ZStack {
            // Gradient: zenith to horizon
            LinearGradient(
                stops: stops,
                startPoint: UnitPoint(x: skySpec.rendering_logic.start_point[0],
                                      y: skySpec.rendering_logic.start_point[1]),
                endPoint: UnitPoint(x: skySpec.rendering_logic.end_point[0],
                                    y: skySpec.rendering_logic.end_point[1])
            )
            .frame(width: viewport.width,
                   height: viewport.height * contract.spatial_framework.global_horizon_y)
            .frame(width: viewport.width, height: viewport.height, alignment: .top)

            // Sky_Inv_04: clamp — fill below horizon with last stop color
            if let lastStop = skySpec.gradient_stops.last {
                Color(cgColor: .fromHex(lastStop.hex))
                    .frame(width: viewport.width,
                           height: viewport.height * (1.0 - contract.spatial_framework.global_horizon_y))
                    .frame(width: viewport.width, height: viewport.height, alignment: .bottom)
            }
        }
        .frame(width: viewport.width, height: viewport.height)
    }
}

// MARK: - Stars View (dumb renderer)

struct StarsView: View {
    let layerId: String
    @ObservedObject var store: SceneStore
    let contract: GlobalSceneContract
    let time: Double

    var body: some View {
        Canvas { context, size in
            guard let stars = store.starCache[layerId] else { return }

            let minDim = min(size.width, size.height)
            let viewW = size.width
            let viewH = size.height

            for star in stars {
                let starSize = CGFloat(star.scale) * minDim

                // Star_Inv_05: pulse frequency <= 0.5Hz
                // For focal star (typeIndex 2): apply pulse
                var alpha = star.alpha
                if star.typeIndex == 2 {
                    let minA = 0.7
                    let pulse = (sin(2.0 * .pi * 0.5 * time) + 1.0) / 2.0
                    alpha = minA + (star.alpha - minA) * pulse
                }

                let rect = CGRect(
                    x: CGFloat(star.x) * viewW - starSize / 2,
                    y: CGFloat(star.y) * viewH - starSize / 2,
                    width: starSize,
                    height: starSize
                )

                let color = Color.white.opacity(alpha)

                if star.typeIndex == 1 || star.typeIndex == 2 {
                    drawFourPointedStar(context: &context, rect: rect, color: color)
                } else {
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }

    private func drawFourPointedStar(context: inout GraphicsContext,
                                     rect: CGRect, color: Color) {
        let cx = rect.midX, cy = rect.midY
        let outer = rect.width / 2.0
        let inner = outer * 0.35

        var path = Path()
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4.0 - .pi / 2.0
            let r = i.isMultiple(of: 2) ? outer : inner
            let pt = CGPoint(x: cx + cos(angle) * r, y: cy + sin(angle) * r)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }
}

// MARK: - Forest Layer View

struct ForestLayerView: View {
    let system: LoadedSystem
    let contract: GlobalSceneContract
    let viewport: CGSize

    var body: some View {
        Canvas { context, size in
            guard let spec = try? JSONDecoder().decode(ForestLayerSpec.self, from: system.rawData) else {
                return
            }

            let pop = spec.population_logic
            let mat = spec.material_properties

            let seed = generateStableSeed("\(contract.contract_id)|\(spec.system_id)")
            var rng = SeededRandomNumberGenerator(seed: seed)

            let yMin = pop.y_band_normalized[0]
            let yMax = pop.y_band_normalized[1]
            let exclusion = pop.corridor_exclusion_x

            // Layer 0 is the only layer that must root at the immersion floor
            let isLayer0 = spec.references.layer_id == "trees_layer_0"
            let floorY = CGFloat(contract.spatial_framework.immersion_floor_y) * size.height

            var drawContext = context
            if isLayer0 {
                drawContext.clip(
                    to: Path(
                        CGRect(
                            x: 0,
                            y: 0,
                            width: size.width,
                            height: floorY
                        )
                    )
                )
            }

            var placed = 0
            var attempts = 0
            let maxAttempts = pop.count * 10

            while placed < pop.count && attempts < maxAttempts {
                attempts += 1

                let xNorm = nextDouble(&rng)
                let yNorm = yMin + nextDouble(&rng) * (yMax - yMin)

                // Corridor exclusion invariant
                if let excl = exclusion, xNorm > excl[0] && xNorm < excl[1] {
                    continue
                }

                let speciesIdx = pop.variant_registry[placed % pop.variant_registry.count]
                let treePath = TreeAssetRegistry.swiftUIPath(for: speciesIdx, in: size)

                // Root anchoring via actual path bounds
                let bounds = treePath.boundingRect
                let rootLocal = CGPoint(x: bounds.midX, y: bounds.maxY)

                let treeX = CGFloat(xNorm) * size.width
                let treeY = CGFloat(yNorm) * size.height
                let scale = CGFloat(mat.scale_factor)

                // Clamp root to immersion floor for layer 0 only
                let rootY = isLayer0 ? max(treeY, floorY) : treeY

                var ctx = drawContext
                ctx.opacity = mat.opacity

                // Correct transform order:
                // 1) world translate to root
                // 2) scale
                // 3) translate local root to origin
                ctx.translateBy(x: treeX, y: rootY)
                ctx.scaleBy(x: scale, y: scale)
                ctx.translateBy(x: -rootLocal.x, y: -rootLocal.y)

                // Blur intentionally not applied here.
                // Fog and recession are handled by the fog system.
                let fillColor = adjustedColor(
                    baseHex: mat.base_hex,
                    layerId: spec.references.layer_id
                )

                ctx.fill(treePath, with: .color(fillColor))

                placed += 1
            }
        }
    }

    private func nextDouble(_ rng: inout SeededRandomNumberGenerator) -> Double {
        Double(rng.next()) / Double(UInt64.max)
    }

    private func adjustedColor(baseHex: String, layerId: String) -> Color {
    let base = CGColor.fromHex(baseHex)

    let lift: CGFloat
    switch layerId {
    case "trees_layer_0":
        lift = 0.0
    case "trees_layer_1":
        lift = 0.18
    case "trees_layer_2":
        lift = 0.32
    default:
        lift = 0.0
    }

    guard let comps = base.components, comps.count >= 3 else {
        return Color(cgColor: base)
    }

    return Color(
        red: min(comps[0] + lift, 1.0),
        green: min(comps[1] + lift, 1.0),
        blue: min(comps[2] + lift, 1.0)
    )
}

}

// MARK: - Ground Plate View

struct GroundPlateView: View {
    let system: LoadedSystem
    let contract: GlobalSceneContract
    let viewport: CGSize

    var body: some View {
        guard let spec = try? JSONDecoder().decode(GroundPlateSpec.self, from: system.rawData) else {
            fatalError("GroundPlateView: Failed to decode GroundPlateSpec")
        }

        let geo = spec.geometry_logic
        let mat = spec.material_properties

        // Grd_Inv_01: vertical_anchor_y <= immersion_floor_y
        // Ensures the ground plate is properly rooted within the atmospheric floor.
        precondition(geo.vertical_anchor_y <= contract.spatial_framework.immersion_floor_y,
                     "GroundPlateView: Grd_Inv_01 violated — anchor_y exceeds immersion_floor_y")

        let anchorY = CGFloat(geo.vertical_anchor_y) * viewport.height
        let plateH  = CGFloat(geo.height_normalized) * viewport.height
        
        // Grd_Inv_04: Alpha feathering calculation.
        // Converts absolute viewport normalized coordinates into relative locations for the mask gradient.
        let relStart = CGFloat((geo.top_edge_feather_band[0] - geo.vertical_anchor_y) / geo.height_normalized)
        let relEnd   = CGFloat((geo.top_edge_feather_band[1] - geo.vertical_anchor_y) / geo.height_normalized)

        return ZStack(alignment: .top) {
            // Grd_Inv_05: Organic visual mass (Asset-driven texture backed by base shadow density).
            // Grd_Inv_03: base_hex ensures ground remains the darkest terrestrial element.
            Image(mat.texture_ref)
                .resizable(resizingMode: .tile)
                .background(Color(cgColor: .fromHex(mat.base_hex)))
                .frame(width: viewport.width, height: plateH)
                // Grd_Inv_04: Alpha feathering (non-procedural) to blend naturally upward.
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: Double(relStart)),
                            .init(color: .black, location: Double(relEnd))
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(width: viewport.width, height: viewport.height, alignment: .top)
        .offset(y: anchorY)
    }
}
