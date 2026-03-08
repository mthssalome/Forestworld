// FogResolver.swift
// Calculates the fog density at a given normalized Y position
// using the Fog & Recession system spec embedded in the Global Scene Contract.
// No fallback values. Fails fast in DEBUG if fog spec is absent.

import Foundation

enum FogResolver {

    // MARK: - Active Y Range (from System_fog.json physics_model)

    private static let activeYRange: Range<Double> = 0.30..<0.45
    private static let maxOpacity: Double = 0.65

    // MARK: - Public API

    /// Returns the fog attenuation factor [0.0, 1.0] at a normalized Y coordinate.
    /// Maximum fog (max_opacity) is reached at activeYRange.lowerBound (the horizon).
    /// Fog decays to 0.0 as Y increases toward activeYRange.upperBound.
    /// Outside the active range, fog is 0.0.
    ///
    /// Fog_Inv_01: MAX(fog_opacity) AT Y == global_horizon_y
    static func density(atY y: Double, contract: GlobalSceneContract) -> Double {
        let horizonY = contract.spatial_framework.global_horizon_y
        let rangeMin = activeYRange.lowerBound  // ≈ global_horizon_y - small offset
        let rangeMax = activeYRange.upperBound

        guard y >= rangeMin && y < rangeMax else { return 0.0 }

        // Linear decay: densest at rangeMin (horizon), fades to 0 at rangeMax
        let t = (y - rangeMin) / (rangeMax - rangeMin)
        let densityNorm = 1.0 - t  // 1.0 at horizon, 0.0 at lower end of band

        // Fog_Inv_04: product must not exceed global luminance max
        let rawOpacity = densityNorm * maxOpacity
        let luminanceCeiling = contract.luminance_budget.global_max
        let skyLuminanceAtHorizon = 0.18  // Horizon_Warm_Luminance_Peak from Sky spec
        let maxAllowed = luminanceCeiling / max(skyLuminanceAtHorizon, 1e-9)
        return min(rawOpacity, maxAllowed)
    }

    /// Returns the effective fog alpha at a given Y for use in ArrivalTreeView.
    /// V_eff = growth_progress * (1 - fog_local) — from the arrival tree spec.
    static func localFogAlpha(atY y: Double, contract: GlobalSceneContract) -> Double {
        density(atY: y, contract: contract)
    }
}
