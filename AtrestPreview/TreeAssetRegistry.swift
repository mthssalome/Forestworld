// TreeAssetRegistry.swift
// Single Source of Truth for 8-species organic tree taxonomy (indices 0–7)
// and the 128-point normalized morph paths for the Arrival Tree (indices 8–9).
// All data is sourced from TreePaths_v1.json — no hardcoded path strings.

import CoreGraphics
import Foundation
import SwiftUI

enum TreeAssetRegistry {

    // MARK: - Loaded State (populated by SceneStore from TreePaths_v1.json)

    private(set) static var loadedRegistry: TreePathsRegistry?

    static func configure(with registry: TreePathsRegistry) {
        loadedRegistry = registry
    }

    // MARK: - Species SVG Path (String) for indices 0–7

    /// Returns the canonical SVG path string for a given species index.
    /// Calls fatalError in DEBUG if index is out of range.
    static func path(for index: Int) -> String {
        guard let reg = loadedRegistry else {
            fatalError("TreeAssetRegistry: Registry not configured. Call configure(with:) before use.")
        }
        guard let entry = reg.species[String(index)] else {
            #if DEBUG
            fatalError("TreeAssetRegistry: Species index \(index) does not exist in TreePaths_v1.json")
            #else
            return reg.species["0"]!.svg_path
            #endif
        }
        return entry.svg_path
    }

    // MARK: - Normalized CGPoint Path for Morph (indices 8–9)

    /// Returns the canonical 128-point normalized [CGPoint] for sapling (8) or hero (9).
    static func normalizedPath(for index: Int) -> [CGPoint] {
        guard let reg = loadedRegistry else {
            fatalError("TreeAssetRegistry: Registry not configured. Call configure(with:) before use.")
        }
        guard let morph = reg.morph_paths[String(index)] else {
            fatalError("TreeAssetRegistry: Morph path index \(index) not found in TreePaths_v1.json")
        }
        guard morph.points.count == 128 else {
            fatalError("TreeAssetRegistry: Morph path \(index) must have exactly 128 points, found \(morph.points.count)")
        }
        return morph.points.map { pair in
            guard pair.count == 2 else {
                fatalError("TreeAssetRegistry: Malformed point in morph path \(index)")
            }
            return CGPoint(x: pair[0], y: pair[1])
        }
    }

    // MARK: - SwiftUI Path from SVG D String (species 0–7)

    /// Converts a simplified M/L/Z SVG path string (1024×1024 canvas) to a SwiftUI Path.
    /// Supports M (moveto), L (lineto), Z (closepath) only.
    static func swiftUIPath(for index: Int, in size: CGSize) -> Path {
        let svgString = path(for: index)
        let scaleX = size.width  / 1024.0
        let scaleY = size.height / 1024.0
        return parseSVGPath(svgString, scaleX: scaleX, scaleY: scaleY)
    }

    // MARK: - SVG Path Parser (M/L/Z subset)

    static func parseSVGPath(_ d: String, scaleX: CGFloat = 1, scaleY: CGFloat = 1) -> Path {
        var path = Path()
        // Tokenize: split on command letters, keeping the letter
        let tokens = tokenize(d)
        var current = CGPoint.zero

        for token in tokens {
            guard let cmd = token.first else { continue }
            let args = parseArgs(String(token.dropFirst()))

            switch cmd {
            case "M":
                guard args.count >= 2 else { continue }
                current = CGPoint(x: CGFloat(args[0]) * scaleX,
                                  y: CGFloat(args[1]) * scaleY)
                path.move(to: current)
            case "L":
                guard args.count >= 2 else { continue }
                current = CGPoint(x: CGFloat(args[0]) * scaleX,
                                  y: CGFloat(args[1]) * scaleY)
                path.addLine(to: current)
            case "Z", "z":
                path.closeSubpath()
            default:
                break
            }
        }
        return path
    }

    // MARK: - SVG Tokenizer

    private static func tokenize(_ d: String) -> [String] {
        var result: [String] = []
        var current = ""
        for char in d {
            if char.isLetter && char != "e" && char != "E" {
                if !current.isEmpty { result.append(current.trimmingCharacters(in: .whitespaces)) }
                current = String(char)
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { result.append(current.trimmingCharacters(in: .whitespaces)) }
        return result
    }

    private static func parseArgs(_ s: String) -> [Double] {
        // Split by whitespace and commas
        return s.components(separatedBy: CharacterSet(charactersIn: " ,\t\n"))
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }
}
