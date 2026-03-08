// StarGenerator.swift
// Bridson Poisson-disk sampling for the star field.
// All generation is deterministic via FNV-1a seeding (Doc_Inv_02).
// Hardened against out-of-bounds grid writes and seed-point poisoning.

import CoreGraphics
import Foundation

enum StarGenerator {

    private struct Candidate {
        let x: Double
        let y: Double
    }

    // MARK: - Public Entry Point

    static func generate(spec: StarSystemSpec, contract: GlobalSceneContract) -> [StarPoint] {
        // 1. Deterministic seed (Doc_Inv_02: FNV-1a of contract|system)
        let seed = generateStableSeed("\(contract.contract_id)|\(spec.system_id)")
        var rng = SeededRandomNumberGenerator(seed: seed)

        let dist = spec.distribution_logic
        let r = dist.sampling_params.min_distance_normalized
        let boundsY = dist.bounds_y
        let horizonY = contract.spatial_framework.global_horizon_y
        let exclusion = dist.exclusion_zones[0]

        let cellSize = r / sqrt(2.0)
        let gridWidth  = max(1, Int(ceil(1.0 / cellSize)))
        let gridHeight = max(1, Int(ceil(1.0 / cellSize)))
        var grid = [Int?](repeating: nil, count: gridWidth * gridHeight)

        var activeList: [Candidate] = []
        var finalPoints: [Candidate] = []

        // 2. Bounded resampling for valid seed point (max 64 attempts)
        var seedPoint: Candidate?
        for _ in 0..<64 {
            let cx = randomDouble(in: 0.0..<1.0, using: &rng)
            let cy = randomDouble(in: boundsY[0]..<min(boundsY[1], horizonY), using: &rng)
            let candidate = Candidate(x: cx, y: cy)
            if abs(candidate.x - exclusion.center_x) >= exclusion.radius_x {
                seedPoint = candidate
                break
            }
        }

        guard let seed0 = seedPoint else {
            #if DEBUG
            fatalError("StarGenerator: Unable to find valid seed point in 64 attempts. Check corridor/bounds spec.")
            #else
            return []
            #endif
        }

        addPoint(seed0, to: &finalPoints, grid: &grid,
                 activeList: &activeList, gridWidth: gridWidth,
                 gridHeight: gridHeight, cellSize: cellSize)

        // 3. Main Bridson sampling loop
        while !activeList.isEmpty {
            let index = Int(randomDouble(in: 0.0..<Double(activeList.count), using: &rng))
            let center = activeList[index]
            var found = false

            for _ in 0..<dist.sampling_params.max_candidates {
                let angle = randomDouble(in: 0.0..<(2.0 * .pi), using: &rng)
                let dist2 = randomDouble(in: r..<(2.0 * r), using: &rng)
                let cx = center.x + cos(angle) * dist2
                let cy = center.y + sin(angle) * dist2
                let pt = Candidate(x: cx, y: cy)

                if isValid(pt, r: r,
                           boundsY: boundsY, horizonY: horizonY,
                           exclusion: exclusion,
                           grid: &grid, gridWidth: gridWidth,
                           gridHeight: gridHeight, cellSize: cellSize,
                           points: finalPoints) {
                    addPoint(pt, to: &finalPoints, grid: &grid,
                             activeList: &activeList, gridWidth: gridWidth,
                             gridHeight: gridHeight, cellSize: cellSize)
                    found = true
                    break
                }
            }
            if !found { activeList.remove(at: index) }
        }

        // 4. Map raw candidates to StarPoints
        return mapToStarPoints(finalPoints, spec: spec, rng: &rng, contract: contract)
    }

    // MARK: - Validation

    private static func isValid(_ pt: Candidate,
                                r: Double,
                                boundsY: [Double],
                                horizonY: Double,
                                exclusion: StarSystemSpec.DistributionLogic.ExclusionZone,
                                grid: inout [Int?],
                                gridWidth: Int,
                                gridHeight: Int,
                                cellSize: Double,
                                points: [Candidate]) -> Bool {
        // Star_Inv_02: strictly above horizon
        guard pt.x >= 0, pt.x < 1.0,
              pt.y >= boundsY[0], pt.y < min(boundsY[1], horizonY) else { return false }

        // Corridor exclusion (weighted)
        if abs(pt.x - exclusion.center_x) < exclusion.radius_x { return false }

        let gx = min(gridWidth  - 1, max(0, Int(pt.x / cellSize)))
        let gy = min(gridHeight - 1, max(0, Int(pt.y / cellSize)))

        for nx in max(0, gx - 2)...min(gridWidth - 1, gx + 2) {
            for ny in max(0, gy - 2)...min(gridHeight - 1, gy + 2) {
                if let idx = grid[nx + ny * gridWidth] {
                    let other = points[idx]
                    let dx = pt.x - other.x
                    let dy = pt.y - other.y
                    if dx * dx + dy * dy < r * r { return false }
                }
            }
        }
        return true
    }

    // MARK: - Add Point (grid-safe)

    private static func addPoint(_ pt: Candidate,
                                 to points: inout [Candidate],
                                 grid: inout [Int?],
                                 activeList: inout [Candidate],
                                 gridWidth: Int,
                                 gridHeight: Int,
                                 cellSize: Double) {
        let index = points.count
        points.append(pt)
        activeList.append(pt)
        let gx = min(gridWidth  - 1, max(0, Int(pt.x / cellSize)))
        let gy = min(gridHeight - 1, max(0, Int(pt.y / cellSize)))
        grid[gx + gy * gridWidth] = index
    }

    // MARK: - Map to StarPoint

    private static func mapToStarPoints(_ points: [Candidate],
                                        spec: StarSystemSpec,
                                        rng: inout SeededRandomNumberGenerator,
                                        contract: GlobalSceneContract) -> [StarPoint] {
        let maxLuminance = contract.luminance_budget.global_max
        var result: [StarPoint] = []

        // Build a weighted population table
        let totalWeight = spec.star_types.reduce(0.0) { $0 + $1.population_weight }
        var cumulative: [(threshold: Double, type: StarSystemSpec.StarType)] = []
        var acc = 0.0
        for t in spec.star_types {
            acc += t.population_weight / totalWeight
            cumulative.append((acc, t))
        }

        // Star_Inv_04: exactly one arrival_star_focal injected at fixed position
        var hasFocal = false

        for pt in points {
            let roll = randomDouble(in: 0.0..<1.0, using: &rng)
            let starType = cumulative.first(where: { roll <= $0.threshold })?.type ?? spec.star_types[0]

            let scaleMin = starType.scale_range[0]
            let scaleMax = starType.scale_range[1]
            let scale = randomDouble(in: scaleMin..<max(scaleMin + 1e-9, scaleMax), using: &rng)

            let alphaMin = starType.opacity_range[0]
            let alphaMax = starType.opacity_range[1]
            var alpha = randomDouble(in: alphaMin..<max(alphaMin + 1e-9, alphaMax), using: &rng)

            // Star_Inv_01: luminance guard
            alpha = min(alpha, maxLuminance)

            result.append(StarPoint(x: pt.x, y: pt.y, scale: scale,
                                    alpha: alpha, typeIndex: starType.type_index))
        }

        // Inject focal star exactly once (Star_Inv_04) at center-sky position
        if !hasFocal, let focal = spec.star_types.first(where: { $0.id == "arrival_star_focal" }) {
            result.append(StarPoint(x: 0.50, y: 0.22,
                                    scale: focal.scale_range[0],
                                    alpha: focal.opacity_range[0],
                                    typeIndex: focal.type_index))
        }

        return result
    }

    // MARK: - RNG Helpers

    private static func randomDouble(in range: Range<Double>,
                                     using rng: inout SeededRandomNumberGenerator) -> Double {
        let raw = Double(rng.next()) / Double(UInt64.max)
        return range.lowerBound + raw * (range.upperBound - range.lowerBound)
    }
}
