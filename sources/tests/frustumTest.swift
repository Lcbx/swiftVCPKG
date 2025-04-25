import Foundation
import raylib


func FrustumTest(){
    raylib.SetTargetFPS(60)

    let SQUARE_N = 1000

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
            x: Float(raylib.GetRandomValue(-100, 100)),
            y: Float(raylib.GetRandomValue(-50, 50)),
            z: Float(raylib.GetRandomValue(-100, 100))
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
        position: Vec3(x: 0, y: 100, z: 0),
        target: Vec3(x: 0, y: 0, z: 0),
        up: Vec3(x: 0, y: 0, z: -1),
        fovy: 60.0,
        projection: raylib.CAMERA_PERSPECTIVE.rawValue
    )

    var camera2 = raylib.Camera(
        position: Vec3(x: 10, y: 80, z: 10),
        target: Vec3(x: 0, y: 0, z: 0),
        up: Vec3(x: 0, y: 0, z: -1),
        fovy: 45,
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
            if abs(p.x) > 100 { v.x = -v.x }
            if abs(p.z) > 100 { v.z = -v.z }
            positions[entity] = p
            velocities[entity] = v
        }

        raylib.BeginMode3D(camera2)
        var frustum = createFrustum()
        raylib.EndMode3D()

        //raylib.UpdateCamera(&camera, raylib.CAMERA_FIRST_PERSON.rawValue)
        raylib.BeginMode3D(camera)
        raylib.DrawGrid(25, 2.0);
        
        raylib.DrawSphere(camera2.position, 0.3, raylib.Color(r: 255, g: 255, b: 0, a: 255))
        raylib.DrawLine3D(camera2.position, camera2.target, raylib.Color(r: 200, g: 100, b: 100, a: 255))
        
        //raylib.BeginMode3D(camera2)

        //NOTE: drawing must be on main thread
        //var frustum = createFrustum()
        for (pos, mesh) in ecs.iterate(positions, meshes) {
            let bb = mesh.boundingBox
            let bbCenter = raylib.Vector3Lerp(bb.min, bb.max, 0.5)
            let bbSize = raylib.Vector3Subtract(bb.max, bb.min)
            let transform = raylib.MatrixTranslate(pos.x,pos.y,pos.z)
            let position = raylib.Vector3Transform(bbCenter, transform)

            if frustumFilter(frustum,bb,transform) {
                raylib.DrawCube(position, bbSize.x, bbSize.y, bbSize.z, mesh.color)
            }
            else {
                DrawCubeWires(position, bbSize.x + 0.1, bbSize.z + 0.1, bbSize.y + 0.1, raylib.Color(r:255,g:0,b:0,a:200))
            }
        }

        raylib.EndMode3D()

        positions.upkeep()                                                                                       
        velocities.upkeep()                                                                                      
        meshes.upkeep()
    }


    print("done")
}