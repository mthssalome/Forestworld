// BezierResolver.swift
// Evaluates cubic Bezier easing curves from the canonical_curves contract section.
// Used by ArrivalTreeView to apply growth_materialization easing.
// No defaults. Control points are required to be in [x1, y1, x2, y2] format.

import Foundation

enum BezierResolver {

    // MARK: - Public API

    /// Maps a linear progress value [0, 1] through a cubic Bezier curve.
    /// control_points: [x1, y1, x2, y2] (same format as CSS cubic-bezier).
    /// Solves for t numerically (Newton's method), then evaluates Y(t).
    static func resolve(progress: Double,
                        points: [Double]) -> Double {
        guard points.count == 4 else {
            fatalError("BezierResolver: control_points must have exactly 4 values, got \(points.count)")
        }
        let p1x = points[0], p1y = points[1]
        let p2x = points[2], p2y = points[3]

        // Clamp input
        let x = max(0.0, min(1.0, progress))
        if x == 0.0 { return 0.0 }
        if x == 1.0 { return 1.0 }

        // Solve for t given x using Newton–Raphson iteration
        let t = solveForT(x: x, p1x: p1x, p2x: p2x)

        // Evaluate the Y(t) Bezier
        return cubicBezier(t: t, p1: p1y, p2: p2y)
    }

    // MARK: - Private

    /// Cubic Bezier value — simplified to two control points on unit interval.
    private static func cubicBezier(t: Double, p1: Double, p2: Double) -> Double {
        let mt = 1.0 - t
        // B(t) = 3*mt^2*t*p1 + 3*mt*t^2*p2 + t^3
        return 3 * mt * mt * t * p1 + 3 * mt * t * t * p2 + t * t * t
    }

    /// Derivative of the cubic X component (for Newton's method).
    private static func cubicBezierDerivative(t: Double, p1x: Double, p2x: Double) -> Double {
        let mt = 1.0 - t
        return 3 * mt * mt * p1x + 6 * mt * t * p2x + 3 * t * t
    }

    /// Solve for the parametric t such that BezierX(t) ≈ x.
    private static func solveForT(x: Double, p1x: Double, p2x: Double) -> Double {
        // Initial estimate using linear interpolation
        var t = x
        for _ in 0..<8 {
            let bx = cubicBezier(t: t, p1: p1x, p2: p2x) - x
            let dt = cubicBezierDerivative(t: t, p1x: p1x, p2x: p2x)
            guard abs(dt) > 1e-9 else { break }
            t -= bx / dt
            t = max(0.0, min(1.0, t))
        }
        return t
    }
}
