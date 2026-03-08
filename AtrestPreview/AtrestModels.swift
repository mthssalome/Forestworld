// AtrestModels.swift
// GlobalSceneContract, SystemSpec, GrowthRegistry, and all DTOs.
// All types are Decodable and mirror JSON keys exactly — no renaming, no defaults.

import CoreGraphics
import Foundation

// MARK: - Global Scene Contract (v7)

struct GlobalSceneContract: Decodable {
    let contract_id: String
    let spatial_framework: SpatialFramework
    let depth_ordering_bands: [String: Int]
    let parallax_bands: [String: Double]
    let luminance_budget: LuminanceBudget
    let interactivity: Interactivity
    let canonical_curves: CanonicalCurves

    struct SpatialFramework: Decodable {
        let coordinate_system: String
        let axis_origin: String
        let aspect_ratio_policy: String
        let global_horizon_y: Double
        let immersion_floor_y: Double
        let parallax_vector_policy: ParallaxVectorPolicy
        let parallax_vector_overrides: [String: ParallaxVectorPolicy]?

        struct ParallaxVectorPolicy: Decodable {
            let x_multiplier: Double
            let y_multiplier: Double
        }
    }

    struct LuminanceBudget: Decodable {
        let global_min: Double
        let global_max: Double
        let silhouette_contrast_target: Double
    }

    struct Interactivity: Decodable {
        let camera_drift: CameraDrift
        let scroll_response: ScrollResponse
        let rest_state_attenuation: RestStateAttenuation

        struct CameraDrift: Decodable {
            let amplitude_x: Double
            let amplitude_y: Double
            let frequency_hz: Double
            let easing: String
            let seed_drift: Int
        }

        struct ScrollResponse: Decodable {
            let damping: Double
            let velocity_multiplier: Double
            let max_offset_limit: Double
        }

        struct RestStateAttenuation: Decodable {
            let progress_hinge: Double
            let drift_multiplier_at_zero: Double
            let warmth_multiplier_at_zero: Double
            let logic: String
        }
    }

    struct CanonicalCurves: Decodable {
        let growth_materialization: CurveDefinition

        struct CurveDefinition: Decodable {
            let control_points: [Double]
        }
    }
}

// MARK: - System Spec (base, shared across all system JSON files)

struct SystemSpec: Decodable {
    let system_id: String
    let references: References
    let invariants: [String]?

    struct References: Decodable {
        let contract: String
        let layer_id: String
        let parallax_id: String
        let fog_ref: String?
        let mask_ref: String?
    }
}

// MARK: - Loaded System (decoded spec + raw bundle data)

struct LoadedSystem {
    let spec: SystemSpec
    let rawData: Data
}

// MARK: - Star System Spec

struct StarSystemSpec: Decodable {
    let system_id: String
    let references: SystemSpec.References
    let distribution_logic: DistributionLogic
    let star_types: [StarType]

    struct DistributionLogic: Decodable {
        let density: Double
        let positioning: String
        let bounds_y: [Double]
        let sampling_params: SamplingParams
        let exclusion_zones: [ExclusionZone]

        struct SamplingParams: Decodable {
            let min_distance_normalized: Double
            let max_candidates: Int
        }

        struct ExclusionZone: Decodable {
            let center_x: Double
            let radius_x: Double
            let weight: Double
        }
    }

    struct StarType: Decodable {
        let id: String
        let type_index: Int
        let population_weight: Double
        let scale_range: [Double]
        let opacity_range: [Double]
    }
}

// MARK: - Star Point (render payload, pre-computed by SceneStore)

struct StarPoint {
    let x: Double
    let y: Double
    let scale: Double
    let alpha: Double
    let typeIndex: Int
}

// MARK: - Growth Registry

struct GrowthRegistry: Decodable {
    let registry_id: String
    let references: RegistryRefs
    let normalization_rules: NormalizationRules
    let states: [GrowthState]

    struct RegistryRefs: Decodable {
        let contract: String
    }

    struct NormalizationRules: Decodable {
        let point_count: Int
        let interpolation_method: String
        let preserve_landmarks: LandmarkSpec

        struct LandmarkSpec: Decodable {
            let indices: [Int]
            let labels: [String]
        }
    }

    struct GrowthState: Decodable {
        let id: String
        let threshold: Double
        let properties: StateProperties

        struct StateProperties: Decodable {
            let opacity: Double
            let scale_mult: Double
            let label: String
        }
    }
}

// MARK: - Tree Paths Registry (TreePaths_v1.json)

struct TreePathsRegistry: Decodable {
    let species: [String: SpeciesEntry]
    let morph_paths: [String: MorphPath]

    struct SpeciesEntry: Decodable {
        let name: String
        let svg_path: String
    }

    struct MorphPath: Decodable {
        let name: String
        let points: [[Double]]
    }
}

// MARK: - Forest Layer Params (decoded from population_logic in each System_forest_* JSON)

struct ForestLayerSpec: Decodable {
    let system_id: String
    let references: SystemSpec.References
    let population_logic: PopulationLogic
    let material_properties: MaterialProperties
    let invariants: [String]?

    struct PopulationLogic: Decodable {
        let count: Int
        let distribution: String
        let y_band_normalized: [Double]
        let corridor_exclusion_x: [Double]?
        let variant_registry: [Int]
    }

    struct MaterialProperties: Decodable {
        let fill_mode: String
        let base_hex: String
        let opacity: Double
        let scale_factor: Double
        let blur_logic: BlurLogic

        struct BlurLogic: Decodable {
            let radius_normalized: Double
            let authority: String
        }
    }
}

// MARK: - Ground Plate Spec

struct GroundPlateSpec: Decodable {
    let system_id: String
    let references: SystemSpec.References
    let geometry_logic: GeometryLogic
    let material_properties: MaterialProperties
    let invariants: [String]?

    struct GeometryLogic: Decodable {
        let type: String
        let vertical_anchor_y: Double
        let height_normalized: Double
        let top_edge_feather_band: [Double]
    }

    struct MaterialProperties: Decodable {
        let fill_mode: String
        let base_hex: String
        let highlight_hex: String
        let texture_ref: String
        let opacity: Double
        let blend_mode: String
    }
}

// MARK: - Sky System Spec

struct SkySystemSpec: Decodable {
    let system_id: String
    let references: SystemSpec.References
    let rendering_logic: RenderingLogic
    let gradient_stops: [GradientStop]

    struct RenderingLogic: Decodable {
        let type: String
        let start_point: [Double]
        let end_point: [Double]
        let clamping_behavior: String
    }

    struct GradientStop: Decodable {
        let offset: Double
        let hex: String
        let label: String
        let luminance: Double
    }
}

// MARK: - Seeded Random Number Generator (FNV-1a 64-bit, Doc_Inv_02)

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64 using the FNV-1a seed as initial state
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - FNV-1a 64-bit Stable Hash (Appendix A)

func generateStableSeed(_ input: String) -> UInt64 {
    let offsetBasis: UInt64 = 14695981039346656037
    let prime: UInt64 = 1099511628211
    var hash = offsetBasis
    for byte in input.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* prime
    }
    return hash
}

// MARK: - Color from Hex

extension CGColor {
    static func fromHex(_ hex: String) -> CGColor {
        var h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        if h.count == 6 { h = "FF" + h }
        guard h.count == 8, let val = UInt64(h, radix: 16) else {
            fatalError("AtrestModels: Invalid hex color '\(hex)'")
        }
        let a = Double((val >> 24) & 0xFF) / 255.0
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8)  & 0xFF) / 255.0
        let b = Double((val >> 0)  & 0xFF) / 255.0
        return CGColor(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Linear Interpolation Helpers

@inline(__always)
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

@inline(__always)
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}

@inline(__always)
func lerpPoint(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
    CGPoint(x: lerp(a.x, b.x, CGFloat(t)), y: lerp(a.y, b.y, CGFloat(t)))
}
