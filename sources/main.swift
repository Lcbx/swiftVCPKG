import Foundation
import raylib
import raygui
import pocketpy

#if DEBUG
    print("Debug")
#else
    print("Release")
#endif

// TODO : rewrite using this
// https://noino.substack.com/p/raylib-graphics-shading

let WINDOW_SIZE = Vec2(x:800, y:400)

InitWindow(Int32(WINDOW_SIZE.x), Int32(WINDOW_SIZE.y), "hello world")
SetTargetFPS(60)

//FrustumTest()

let SQUARE_N : Int = 10
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
    public var color : Color
    public var boundingBox : BoundingBox
    //public var data : Model
}


var ecs = ECScene()

ecs.Component(Position.self)
ecs.Component(Velocity.self)
ecs.Component(Mesh.self)



for i in ecs.createEntities(SQUARE_N){
    let entity = ecs[i]
    entity.add(Position(
        x: Float(GetRandomValue(-SPACE_SIZE, SPACE_SIZE)),
        y: Float(GetRandomValue(0, 25)),
        z: Float(GetRandomValue(-SPACE_SIZE, SPACE_SIZE))
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
    position: Vec3(x:30, y: 70, z: -30),
    target: Vec3(x: 0, y: 0, z: -30),
    up: Vec3(x: 0, y: 1, z: 0),
    fovy: 60.0,
    projection: CAMERA_PERSPECTIVE.rawValue
)


var lightCamera = Camera3D(
    position: Vector3(x: -10, y: 35, z: -10),
    target: Vector3(x: 0, y: 0, z: 0),
    up: Vector3(x: 0, y: 1, z: 0),
    fovy: 60.0,
    //projection: CAMERA_PERSPECTIVE.rawValue // depth buffer empty ?
	projection: CAMERA_ORTHOGRAPHIC.rawValue
)

let positions = ecs.list(Position.self)
let velocities = ecs.list(Velocity.self)
let meshes = ecs.list(Mesh.self)


// Load shaders
//let sceneShader = LoadShaderFromMemory("""vs""", """fs""")
let shader_root = "../sources/rendering/shaders/"
var sceneShader = LoadShader(shader_root + "lightmap.vs", shader_root + "lightmap.fs")


var shadowmap = shadowBuffer(1024,1024)

while !WindowShouldClose()
{
    let frameTime = Float(GetFrameTime())
	
    ecs.iterateWithEntity(positions, velocities).parallelFor {
        var (entity, p, v) = $0
        p.x += v.x * frameTime                                                                                      
        p.z += v.z * frameTime                                                                                       
        if abs(p.x) > Float(SPACE_SIZE) { v.x = -v.x }
        if abs(p.z) > Float(SPACE_SIZE) { v.z = -v.z }
        positions[entity] = p
        velocities[entity] = v
    }
	
	
	if IsKeyPressed(KEY_R.rawValue){
		{
			let newShader = LoadShader(shader_root + "lightmap.vs", shader_root + "lightmap.fs")
			guard newShader.id > 0 else { return }
			sceneShader = newShader
		}()
	}
	
    BeginDrawing()
	//rlEnableBackfaceCulling()
	
	BeginTextureMode(shadowmap)
        ClearBackground(RAYWHITE)
        BeginMode3D(lightCamera)
		// does not help shadow acne ?
		//rlSetCullFace(RL_CULL_FACE_FRONT.rawValue)
        
		drawScene()
		
		// for later
        let matLightVP = MatrixMultiply(rlGetMatrixModelview(), rlGetMatrixProjection())
		
		//rlSetCullFace(RL_CULL_FACE_BACK.rawValue)
        EndMode3D()
    EndTextureMode()
	
	
    ClearBackground(RAYWHITE)

    defer {
        DrawText("\(GetFPS())", 10, 10, 20, LIGHTGRAY) 
        EndDrawing()
    }      


	
	drawshadowmap()
    
	BeginMode3D(camera)
	
	DrawSphere(lightCamera.position, 0.6, Color(r: 200, g: 100, b: 0, a: 255))
	DrawLine3D(lightCamera.position, lightCamera.target, Color(r: 250, g: 50, b: 30, a: 255))
	
	BeginShaderMode(sceneShader)
	
	SetShaderValueMatrix(sceneShader,GetShaderLocation(sceneShader,"matLightVP"),matLightVP)
	SetShaderValueTexture(sceneShader,GetShaderLocation(sceneShader,"texture_shadowmap"),shadowmap.depth)
	
	
	
	drawScene()
	
	EndShaderMode()
	EndMode3D()

    positions.upkeep()                                                                                       
    velocities.upkeep()                                                                                      
    meshes.upkeep()
}
CloseWindow()

func drawScene(){
	DrawCube(Vector3(x: 0, y: -1, z: 0), 50, 1, 50, LIGHTGRAY)

    //NOTE: drawing must be on main thread
    var frustum = createFrustum()
    for (pos, mesh) in ecs.iterate(positions, meshes) {
        let bb = mesh.boundingBox
        let bbCenter = Vector3Lerp(bb.min, bb.max, 0.5)
        let bbSize = Vector3Subtract(bb.max, bb.min)
        let transform = MatrixTranslate(pos.x,pos.y,pos.z)
        let position = Vector3Transform(bbCenter, transform)

        guard frustumFilter(frustum,bb,transform) else { continue }
        DrawCube(position, bbSize.x, bbSize.y, bbSize.z, mesh.color)
    }
}

func drawshadowmap(){
    let display_size = WINDOW_SIZE.x / 5.0
    let display_scale = display_size / Float(shadowmap.depth.width)
    DrawTextureEx(shadowmap.texture, Vec2(x:WINDOW_SIZE.x - display_size,y:0.0), 0.0, display_scale, RAYWHITE)
    DrawTextureEx(shadowmap.depth, Vec2(x:WINDOW_SIZE.x - display_size,y: display_size), 0.0, display_scale, RAYWHITE)
}

func shadowBuffer(_ width : Int32, _ height:Int32) -> RenderTexture2D {
    //var target = LoadRenderTexture(width, height)
	var target = RenderTexture2D()
    target.id = rlLoadFramebuffer()
	
    if target.id > 0 {
        rlEnableFramebuffer(target.id)

        // colour component, this is basically unused but i couldnt be bothered working a fragment shader without it.
        // let opengl do the depth calculation internally this way
        target.texture.id = rlLoadTexture(nil, width, height, PIXELFORMAT_UNCOMPRESSED_R8G8B8A8.rawValue, 1)
        target.texture.width = width
        target.texture.height = height
        target.texture.format = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8.rawValue // encode colour as 4 8 bit floats
        target.texture.mipmaps = 1

        // disable renderbuffer, use a texture instead for depth
        target.depth.id = rlLoadTextureDepth(width, height, false)
        target.depth.width = width
        target.depth.height = height
        target.depth.format = PIXELFORMAT_UNCOMPRESSED_R32.rawValue // encode depth as a single 32bit float
        target.depth.mipmaps = 1

        // bind textures to framebuffer, note RL_ATTACHMENT_DEPTH for depth component
        rlFramebufferAttach(target.id, target.texture.id, RL_ATTACHMENT_COLOR_CHANNEL0.rawValue, RL_ATTACHMENT_TEXTURE2D.rawValue, 0)
        rlFramebufferAttach(target.id, target.depth.id, RL_ATTACHMENT_DEPTH.rawValue, RL_ATTACHMENT_TEXTURE2D.rawValue, 0)

        rlDisableFramebuffer()
    }   
    return target
}