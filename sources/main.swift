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

InitWindow(Int32(WINDOW_SIZE.x), Int32(WINDOW_SIZE.y), "Frustum culling example")
SetTargetFPS(60)

let SQUARE_N = 500

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
}


struct Mesh : Component{
    static var typeId = TypeId(Self.self)
    public var color : Color
    public var boundingBox : BoundingBox
    //public var data : Model
}


var ecs = ECScene();

ecs.Component(Position.self)
ecs.Component(Velocity.self)
ecs.Component(Mesh.self)



for i in ecs.createEntities(SQUARE_N){
    let entity = ecs[i]
    entity.add(Position(x: Float(GetRandomValue(-100, 100)),
                        y: Float(GetRandomValue(-100, 100)),
                        z: Float(GetRandomValue(-50, 50))
    ))
    entity.add(Velocity(x: Float(GetRandomValue(-100, 100))/25.0,
                        y: Float(GetRandomValue(-100, 100))/25.0
    ))
    entity.add(Mesh(color:rnd_color(),
        boundingBox:BoundingBox(
        min: Vec3(x:Float(GetRandomValue(-5, 0)), y:Float(GetRandomValue(-5, 0)), z:Float(GetRandomValue(-5, 0))),
        max: Vec3(x:Float(GetRandomValue(1, 5)), y:Float(GetRandomValue(1, 5)), z:Float(GetRandomValue(1, 5))))
    ))
}

var camera = Camera(
    position: Vec3(x: 0, y: 100, z: 0),
    target: Vec3(x: 0, y: 0, z: 0),
    up: Vec3(x: 0, y: 0, z: -1),
    fovy: 60.0,
    projection: CAMERA_PERSPECTIVE.rawValue
)

var camera2 = Camera(
    position: Vec3(x: 10, y: 80, z: 10),
    target: Vec3(x: 0, y: 0, z: 0),
    up: Vec3(x: 0, y: 0, z: -1),
    fovy: 45,
    projection: CAMERA_PERSPECTIVE.rawValue
)

let positions = ecs.list(Position.self)
let velocities = ecs.list(Velocity.self)
let meshes = ecs.list(Mesh.self)

var use_main_camera = true

while !WindowShouldClose()
{
	if IsKeyPressed(KEY_S.rawValue){
		use_main_camera = !use_main_camera
	}
	
    let frameTime = Float(GetFrameTime())
    BeginDrawing()
    ClearBackground(RAYWHITE)
    //DrawGrid(25, 2.0);

    defer {
        DrawText("\(GetFPS())", 10, 10, 20, BLACK)
        DrawText("press S to switch viewpoint", 10, 25, 20, BLACK)
        EndDrawing()
    }      

    for(entity, var p, var v) in ecs.iterateWithEntity(positions, velocities) {
        p.x += v.x * frameTime                                                                                      
        p.y += v.y * frameTime                                                                                       
        if abs(p.x) > 100 { v.x = -v.x }
        if abs(p.y) > 100 { v.y = -v.y }
        positions[entity] = p
        velocities[entity] = v
    }

    BeginMode3D(camera2)
    var frustum = createFrustum(camera2)

	if use_main_camera {
		EndMode3D()
		//UpdateCamera(&camera, CAMERA_FIRST_PERSON.rawValue)
		BeginMode3D(camera)
		DrawSphere(camera2.position, 0.5, Color(r: 250, g: 250, b: 0, a: 255))
		DrawLine3D(camera2.position, camera2.target, BLACK)
	}

    //NOTE: drawing must be on main thread
    for (pos, mesh) in ecs.iterate(positions, meshes) {
        let bb = mesh.boundingBox
        let bbCenter = Vector3Lerp(bb.min, bb.max, 0.5)
        let bbSize = Vector3Subtract(bb.max, bb.min)
        let transform = MatrixTranslate(pos.x,pos.z,pos.y)
        let position = Vector3Transform(bbCenter, transform)

        if frustumFilter(frustum,bb,transform) {
            DrawCube(position, bbSize.x, bbSize.z, bbSize.y, mesh.color)
        }
        else {
            DrawCubeWires(position, bbSize.x + 0.1, bbSize.z + 0.1, bbSize.y + 0.1, Color(r:255,g:0,b:0,a:200))
        }
    }

    EndMode3D()

    positions.upkeep()                                                                                       
    velocities.upkeep()                                                                                      
    meshes.upkeep()
}
CloseWindow()
