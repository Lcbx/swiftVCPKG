import Foundation
import raylib
import raygui
import pocketpy

#if DEBUG
    print("Debug")
#else
    print("Release")
#endif


let WINDOW_SIZE = Vec2(x:800, y:400)

raylib.InitWindow(Int32(WINDOW_SIZE.x), Int32(WINDOW_SIZE.y), "hello world")
raylib.SetTargetFPS(60)

//FrustumTest()

let SQUARE_N : Int = 100
let SPACE_SIZE : Int32 = 30

struct Position : Component {
    static var typeId = TypeId(Self.self)
    public var x : Float
    public var y : Float
    public var z : Float
}
struct Velocity : Component {
    static var typeId = TypeId(Self.self)
    public var x : Float
    public var y : Float
    public var z : Float
}


struct Mesh : Component{
    static var typeId = TypeId(Self.self)
    public var color : raylib.Color
    public var boundingBox : raylib.BoundingBox
    //public var data : raylib.Model
}


var ecs = ECScene();

ecs.Component(Position.self)
ecs.Component(Velocity.self)
ecs.Component(Mesh.self)



for i in ecs.createEntities(SQUARE_N){
    let entity = ecs[i]
    entity.add(Position(
        x: Float(raylib.GetRandomValue(-SPACE_SIZE, SPACE_SIZE)),
        y: Float(raylib.GetRandomValue(-25, 25)),
        z: Float(raylib.GetRandomValue(-SPACE_SIZE, SPACE_SIZE))
    ))
    entity.add(Velocity(
        x: Float(raylib.GetRandomValue(-100, 100))/25.0,
        y: 0,
        z: Float(raylib.GetRandomValue(-100, 100))/25.0
    ))
    entity.add(Mesh(color:rnd_color(),
        boundingBox:raylib.BoundingBox(
        min: Vec3(x:Float(raylib.GetRandomValue(-5, 0)), y:Float(raylib.GetRandomValue(-5, 0)), z:Float(raylib.GetRandomValue(-5, 0))),
        max: Vec3(x:Float(raylib.GetRandomValue(1, 5)), y:Float(raylib.GetRandomValue(1, 5)), z:Float(raylib.GetRandomValue(1, 5))))
    ))
}

var camera = raylib.Camera(
    position: Vec3(x: 20, y: 60, z: 20),
    target: Vec3(x: 0, y: 0, z: 0),
    up: Vec3(x: 0, y: 1, z: 0),
    fovy: 60.0,
    projection: raylib.CAMERA_PERSPECTIVE.rawValue
)

let positions = ecs.list(Position.self)
let velocities = ecs.list(Velocity.self)
let meshes = ecs.list(Mesh.self)


while !raylib.WindowShouldClose()
{
    let frameTime = Float(raylib.GetFrameTime())
    raylib.BeginDrawing()
    raylib.ClearBackground(RAYWHITE)

    defer {
        raylib.DrawText("\(raylib.GetFPS())", 10, 10, 20, LIGHTGRAY) 
        raylib.EndDrawing()
    }      


    ecs.iterateWithEntity(positions, velocities).parallelFor {
        var (entity, p, v) = $0
        p.x += v.x * frameTime                                                                                      
        p.z += v.z * frameTime                                                                                       
        if abs(p.x) > Float(SPACE_SIZE) { v.x = -v.x }
        if abs(p.z) > Float(SPACE_SIZE) { v.z = -v.z }
        positions[entity] = p
        velocities[entity] = v
    }

    raylib.BeginMode3D(camera)
    raylib.DrawGrid(25, 2.0);

    //NOTE: drawing must be on main thread
    var frustum = createFrustum(camera)
    for (pos, mesh) in ecs.iterate(positions, meshes) {
        let bb = mesh.boundingBox
        let bbCenter = raylib.Vector3Lerp(bb.min, bb.max, 0.5)
        let bbSize = raylib.Vector3Subtract(bb.max, bb.min)
        let transform = raylib.MatrixTranslate(pos.x,pos.y,pos.z)
        let position = raylib.Vector3Transform(bbCenter, transform)

        guard frustumFilter(frustum,bb,transform) else { continue }
        raylib.DrawCube(position, bbSize.x, bbSize.y, bbSize.z, mesh.color)
    }

    raylib.EndMode3D()

    positions.upkeep()                                                                                       
    velocities.upkeep()                                                                                      
    meshes.upkeep()
}
raylib.CloseWindow()
