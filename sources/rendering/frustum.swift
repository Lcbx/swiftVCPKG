// frustum clip planes
// used for frustum culling
import Foundation
import raylib


func createFrustum(margin: Float = 1.0) -> [Vec4] {
    let projection = raylib.rlGetMatrixProjection()
    let modelview = raylib.rlGetMatrixModelview()
    
    // PMV = projection * modelview
    let clip = raylib.MatrixMultiply(modelview, projection)

    //var frustum = [Vec4](repeating: Vec4(x: 0, y: 0, z: 0, w: 0), count: 6)
    var frustum = [Vec4](repeating: Vec4(x: 0, y: 0, z: 0, w: 0), count: 4)

    // Left plane
    frustum[0] = normalizePlane(x: clip.m3 + clip.m0, y: clip.m7 + clip.m4, z: clip.m11 + clip.m8, w: clip.m15 + clip.m12 + margin)
    // Right plane
    frustum[1] = normalizePlane(x: clip.m3 - clip.m0, y: clip.m7 - clip.m4, z: clip.m11 - clip.m8, w: clip.m15 - clip.m12 + margin)
    // Bottom plane
    frustum[2] = normalizePlane(x: clip.m3 + clip.m1, y: clip.m7 + clip.m5, z: clip.m11 + clip.m9, w: clip.m15 + clip.m13 + margin)
    // Top plane
    frustum[3] = normalizePlane(x: clip.m3 - clip.m1, y: clip.m7 - clip.m5, z: clip.m11 - clip.m9, w: clip.m15 - clip.m13 + margin)
    // Near plane
    //frustum[4] = normalizePlane(x: clip.m3 + clip.m2, y: clip.m7 + clip.m6, z: clip.m11 + clip.m10, w: clip.m15 + clip.m14 + margin)
    // Far plane
    //frustum[5] = normalizePlane(x: clip.m3 - clip.m2, y: clip.m7 - clip.m6, z: clip.m11 - clip.m10, w: clip.m15 - clip.m14 + margin)

    return frustum
}

func normalizePlane(x: Float, y: Float, z: Float, w: Float) -> Vec4 {
    let length = sqrt(x*x + y*y + z*z)
    return Vec4(x: x/length, y: y/length, z: z/length, w: w/length)
}

func frustumFilter(_ frustum: [Vec4], _ bb: raylib.BoundingBox, _ transform: raylib.Matrix) -> Bool {
    // Step 1: Sphere test (fast rejection)
    let centerLocal = raylib.Vector3Lerp(bb.min, bb.max, 0.5)
    let centerWorld = raylib.Vector3Transform(centerLocal, transform)

    let extents = raylib.Vector3Subtract(bb.max, bb.min)
    let radius = 0.25 * raylib.Vector3LengthSqr(extents)

    if !sphereInFrustum(frustum, centerWorld, radius2: radius) {
        return false
    }

    // Step 2: Full AABB test (precise culling)
    // Transform all 8 corners of the bounding box
    let corners = [
        raylib.Vector3Transform(bb.min, transform),
        raylib.Vector3Transform(Vec3(x: bb.max.x, y: bb.min.y, z: bb.min.z), transform),
        raylib.Vector3Transform(Vec3(x: bb.min.x, y: bb.max.y, z: bb.min.z), transform),
        raylib.Vector3Transform(Vec3(x: bb.max.x, y: bb.max.y, z: bb.min.z), transform),
        raylib.Vector3Transform(Vec3(x: bb.min.x, y: bb.min.y, z: bb.max.z), transform),
        raylib.Vector3Transform(Vec3(x: bb.max.x, y: bb.min.y, z: bb.max.z), transform),
        raylib.Vector3Transform(Vec3(x: bb.min.x, y: bb.max.y, z: bb.max.z), transform),
        raylib.Vector3Transform(bb.max, transform),
    ]

    if corners.contains(where: { pointInFrustum(frustum, $0) }) {
        return true
    }

    // Second check: if all 8 points are outside any one plane, the box is outside
    for plane in frustum {
        if !corners.contains(where: { distanceToPlane(plane, $0) >= 0 }) {
            return false
        }
    }

    // Box intersects the frustum
    return true
}

func pointInFrustum(_ frustum: [Vec4], _ position: Vec3) -> Bool {

    for plane in frustum {
        if distanceToPlane(plane, position) <= 0 {
            return false
        }
    }
    return true
}

func distanceToPlane(_ plane: Vec4, _ position: Vec3) -> Float {
    return plane.x * position.x + plane.y * position.y + plane.z * position.z + plane.w
}

func sphereInFrustum(_ frustum: [Vec4], _ center: Vec3, radius2: Float) -> Bool {

    for plane in frustum {
        let d = distanceToPlane(plane, center)
        if d < 0 && d*d > radius2 {
            return false
        }
    }
    return true
}