import Foundation
import raylib


func FrustumTest(){
	SetWindowTitle("Frustum culling example"); 
    SetTargetFPS(60)

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
        entity.add(Position(
            x: Float(GetRandomValue(-100, 100)),
            y: Float(GetRandomValue(-50, 50)),
            z: Float(GetRandomValue(-100, 100))
        ))
        entity.add(Velocity(
            x: Float(GetRandomValue(-100, 100))/25.0,
            y: 0,
            z: Float(GetRandomValue(-100, 100))/25.0
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

	var useMainCamera = true;
    while !WindowShouldClose()
    {
        let frameTime = Float(GetFrameTime())
        BeginDrawing()
        ClearBackground(RAYWHITE)

        defer {
            DrawText("\(GetFPS())", 10, 10, 20, LIGHTGRAY)
			DrawText("press S to switch viewpoints", 10, 30, 20, LIGHTGRAY)
            EndDrawing()
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

        BeginMode3D(camera2)
        var frustum = createFrustum()
        
		if IsKeyPressed(KEY_S.rawValue) {
			useMainCamera = !useMainCamera;
		}
		if useMainCamera {
			EndMode3D()

			BeginMode3D(camera)
			
			DrawSphere(camera2.position, 0.3, Color(r: 255, g: 255, b: 0, a: 255))
			DrawLine3D(camera2.position, camera2.target, Color(r: 200, g: 100, b: 100, a: 255))
		}
		//DrawGrid(25, 2.0)
        

        //NOTE: drawing must be on main thread
        for (pos, mesh) in ecs.iterate(positions, meshes) {
            let bb = mesh.boundingBox
            let bbCenter = Vector3Lerp(bb.min, bb.max, 0.5)
            let bbSize = Vector3Subtract(bb.max, bb.min)
            let transform = MatrixTranslate(pos.x,pos.y,pos.z)
            let position = Vector3Transform(bbCenter, transform)

            if frustumFilter(frustum,bb,transform) {
                DrawCube(position, bbSize.x, bbSize.y, bbSize.z, mesh.color)
            }
            else {
                DrawCubeWires(position, bbSize.x, bbSize.z, bbSize.y, Color(r:255,g:0,b:0,a:200))
            }
        }

        EndMode3D()

        positions.upkeep()                                                                                       
        velocities.upkeep()                                                                                      
        meshes.upkeep()
    }


    print("done")
}