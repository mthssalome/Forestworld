// SceneStore.swift
// Loads, validates, and pre-computes all scene data.
// Owns the star cache and validated system manifests.
// Fail-fast in DEBUG; gracefully disables offending systems in RELEASE.

import Foundation
import Combine

final class SceneStore: ObservableObject {

    // MARK: - Published State

    @Published private(set) var contract: GlobalSceneContract?
    @Published private(set) var orderedSystems: [LoadedSystem] = []
    @Published private(set) var starCache: [String: [StarPoint]] = [:]
    @Published private(set) var growthRegistry: GrowthRegistry?
    @Published private(set) var treePathsRegistry: TreePathsRegistry?

    // MARK: - Manifest (ordered by resource name → resolved by depth band after load)

    private static let systemManifest: [String] = [
        "System_sky",
        "System_stars",
        "System_mountains",
        "System_fog",
        "System_forest_layer_2",
        "System_forest_layer_1",
        "System_forest_layer_0",
        "System_arrival_hero",
        "System_ground_plate"
    ]

    // MARK: - Init

    init() {
        load()
    }

    // MARK: - Load Entry Point

    func load() {
        let decoder = JSONDecoder()

        // 1. Contract — must be first
        let contractData = loadJSON(named: "SceneContract_v7")
        guard let c = try? decoder.decode(GlobalSceneContract.self, from: contractData) else {
            fatalError("SceneStore: Failed to decode SceneContract_v7.json")
        }
        self.contract = c

        // 2. Ancillary registries
        let growthData = loadJSON(named: "GrowthRegistry_v1")
        guard let gr = try? decoder.decode(GrowthRegistry.self, from: growthData) else {
            fatalError("SceneStore: Failed to decode GrowthRegistry_v1.json")
        }
        self.growthRegistry = gr

        let pathsData = loadJSON(named: "TreePaths_v1")
        guard let tp = try? decoder.decode(TreePathsRegistry.self, from: pathsData) else {
            fatalError("SceneStore: Failed to decode TreePaths_v1.json")
        }
        self.treePathsRegistry = tp

        // 3. Systems
        var loaded: [LoadedSystem] = []
        var seenLayerIDs = Set<String>()

        for name in Self.systemManifest {
            let data = loadJSON(named: name)
            guard let spec = try? decoder.decode(SystemSpec.self, from: data) else {
                #if DEBUG
                fatalError("SceneStore: Failed to decode SystemSpec from \(name).json")
                #else
                continue
                #endif
            }

            // Validate contract_id matches
            validateContractID(spec: spec, contract: c, file: name)

            // Validate unique layer_id
            if seenLayerIDs.contains(spec.references.layer_id) {
                #if DEBUG
                fatalError("SceneStore: Duplicate layer_id '\(spec.references.layer_id)' in \(name).json")
                #else
                continue
                #endif
            }
            seenLayerIDs.insert(spec.references.layer_id)

            // Validate parallax_id exists in contract
            validateParallaxID(spec: spec, contract: c, file: name)

            // Validate at least one invariant
            validateInvariantsPresent(spec: spec, file: name)

            let system = LoadedSystem(spec: spec, rawData: data)

            // System-specific pre-computation
            if spec.references.layer_id == "stars" {
                let stars = precomputeStars(data: data, contract: c)
                starCache[spec.references.layer_id] = stars
            }

            loaded.append(system)
        }

        // 4. Sort by depth_ordering_bands
        self.orderedSystems = loaded.sorted {
            let a = c.depth_ordering_bands[$0.spec.references.layer_id] ?? Int.max
            let b = c.depth_ordering_bands[$1.spec.references.layer_id] ?? Int.max
            return a < b
        }
    }

    // MARK: - JSON Loader

    func loadJSON(named name: String) -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            fatalError("SceneStore: Missing bundle resource '\(name).json'")
        }
        guard let data = try? Data(contentsOf: url) else {
            fatalError("SceneStore: Cannot read '\(name).json'")
        }
        return data
    }

    // MARK: - Validation Helpers

    private func validateContractID(spec: SystemSpec, contract: GlobalSceneContract, file: String) {
        guard spec.references.contract == contract.contract_id else {
            #if DEBUG
            fatalError("SceneStore: Contract ID mismatch in \(file).json — expected '\(contract.contract_id)', got '\(spec.references.contract)'")
            #endif
        }
    }

    private func validateParallaxID(spec: SystemSpec, contract: GlobalSceneContract, file: String) {
        guard contract.parallax_bands[spec.references.parallax_id] != nil else {
            #if DEBUG
            fatalError("SceneStore: parallax_id '\(spec.references.parallax_id)' in \(file).json not found in contract.parallax_bands")
            #endif
        }
    }

    private func validateInvariantsPresent(spec: SystemSpec, file: String) {
        guard let invs = spec.invariants, !invs.isEmpty else {
            #if DEBUG
            fatalError("SceneStore: System '\(spec.system_id)' in \(file).json has no invariants declared")
            #endif
        }
    }

    // MARK: - Star Pre-computation

    private func precomputeStars(data: Data, contract: GlobalSceneContract) -> [StarPoint] {
        guard let spec = try? JSONDecoder().decode(StarSystemSpec.self, from: data) else {
            #if DEBUG
            fatalError("SceneStore: Failed to decode StarSystemSpec for pre-computation")
            #else
            return []
            #endif
        }
        return StarGenerator.generate(spec: spec, contract: contract)
    }
}
