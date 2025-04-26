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


var ecs = ECScene();

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
    position: Vec3(x:30, y: 60, z: -20),
    target: Vec3(x: 0, y: 0, z: -20),
    up: Vec3(x: 0, y: 1, z: 0),
    fovy: 60.0,
    projection: CAMERA_PERSPECTIVE.rawValue
)


var lightCamera = Camera3D(
    position: Vector3(x: -10, y: 400, z: -10),
    target: Vector3(x: 0, y: 0, z: 0),
    up: Vector3(x: 0, y: 1, z: 0),
    fovy: 50.0,
    projection: CAMERA_ORTHOGRAPHIC.rawValue
)

let positions = ecs.list(Position.self)
let velocities = ecs.list(Velocity.self)
let meshes = ecs.list(Mesh.self)


// Load shaders
//let sceneShader = LoadShaderFromMemory("""vs""", """fs""")
let shader_root = "../sources/rendering/shaders/"
let sceneShader = LoadShader(shader_root + "lightmap.vs", shader_root + "lightmap.fs")

// Create render texture for shadow map
var shadowMapSize: Int32 = 1024
var shadowMap = LoadRenderTexture(shadowMapSize, shadowMapSize)
//var shadowMap = RenderTexture2D()
attachShadowTexture(&shadowMap, shadowMapSize, shadowMapSize)

// sceneShader.locs[Int(SHADER_LOC_VECTOR_VIEW.rawValue)] = GetShaderLocation(sceneShader, "viewPos")
// var lightDir = Vector3Normalize(Vector3Subtract(lightCamera.target, lightCamera.position))
 var lightColorNormalized = ColorNormalize(Color(r:100,g:100,b:150,a:255))
// let lightDirLoc = GetShaderLocation(sceneShader, "lightDir")
 let lightColLoc = GetShaderLocation(sceneShader, "lightColor")
// SetShaderValue(sceneShader, lightDirLoc, &lightDir, SHADER_UNIFORM_VEC3.rawValue)
 SetShaderValue(sceneShader, lightColLoc, &lightColorNormalized, SHADER_UNIFORM_VEC4.rawValue)
// let ambientLoc = GetShaderLocation(sceneShader, "ambient")
// var ambient = Vec4(x:0.1,y:0.1,z:0.1,w:1.0)
// SetShaderValue(sceneShader, ambientLoc, &ambient, SHADER_UNIFORM_VEC4.rawValue)
 let lightVPLoc = GetShaderLocation(sceneShader, "lightVP")
 let shadowMapLoc = GetShaderLocation(sceneShader, "shadowMap")
// let shadowMapResolutionLoc = GetShaderLocation(sceneShader, "shadowMapResolution")
// SetShaderValue(sceneShader, shadowMapResolutionLoc, &shadowMapSize, SHADER_UNIFORM_INT.rawValue)

SetShaderValueTexture(sceneShader, shadowMapLoc, shadowMap.depth)


// ground
let planeMesh = GenMeshPlane(25.0, 25.0, 1, 1)
let planeModel = LoadModelFromMesh(planeMesh)


while !WindowShouldClose()
{
    let frameTime = Float(GetFrameTime())
    BeginDrawing()
    ClearBackground(RAYWHITE)

    defer {
        DrawText("\(GetFPS())", 10, 10, 20, LIGHTGRAY) 
        EndDrawing()
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


    // shadows
    BeginTextureMode(shadowMap)
    ClearBackground(RAYBLACK)
    BeginMode3D(lightCamera)
    //BeginShaderMode(depthShader)
    rlSetCullFace(RL_CULL_FACE_FRONT.rawValue)

    let lightProj = rlGetMatrixProjection()
    let lightView = rlGetMatrixModelview()
    let lightSpaceMatrix = MatrixMultiply(lightView, lightProj)

    //planeModel.materials[0].shader = depthShader
    
    drawScene()

    rlSetCullFace(RL_CULL_FACE_BACK.rawValue)
    //EndShaderMode()
    EndMode3D()
    EndTextureMode()


    // main scene

    drawShadowMap()


    let temp = planeModel.materials[0].shader
    defer { planeModel.materials[0].shader = temp }

    BeginMode3D(camera)
    BeginShaderMode(sceneShader)

    SetShaderValueMatrix(sceneShader, lightVPLoc, lightSpaceMatrix)

    var slot = 10; // Can be anything 0 to 15, but 0 will probably be taken up
    rlActiveTextureSlot(10);
    rlEnableTexture(shadowMap.depth.id);
    rlSetUniform(shadowMapLoc, &slot, SHADER_UNIFORM_INT.rawValue, 1);

    planeModel.materials[0].shader = sceneShader
    
    drawScene()

    EndShaderMode()
    EndMode3D()


    positions.upkeep()                                                                                       
    velocities.upkeep()                                                                                      
    meshes.upkeep()
}
CloseWindow()

func drawScene(){
    DrawModel(planeModel, Vector3(x: 0, y: -1, z: 0), 3.5, LIGHTGRAY)

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

func drawShadowMap(){
    let display_size = WINDOW_SIZE.x / 5.0
    let display_scale = display_size / Float(shadowMapSize)
    DrawTextureEx(shadowMap.texture, Vec2(x:WINDOW_SIZE.x - display_size,y:0.0), 0.0, display_scale, RAYWHITE)
    DrawTextureEx(shadowMap.depth, Vec2(x:WINDOW_SIZE.x - display_size,y: display_size), 0.0, display_scale, RAYWHITE)
}



func attachShadowTexture(_ target: inout RenderTexture2D, _ width: Int32, _ height: Int32) {
    //var target = RenderTexture2D()
    
    if target.id == 0 {
        target.id = rlLoadFramebuffer() // Load an empty framebuffer
        target.texture.width = width
        target.texture.height = height
    }

    rlEnableFramebuffer(target.id)

    // Create depth texture
    target.depth.id = rlLoadTextureDepth(width, height, false) // useRenderBuffer = false
    target.depth.width = width
    target.depth.height = height
    target.depth.format = PIXELFORMAT_UNCOMPRESSED_R32.rawValue
    target.depth.mipmaps = 1

    // Attach depth texture to FBO
    rlFramebufferAttach(target.id, target.depth.id, RL_ATTACHMENT_DEPTH.rawValue, RL_ATTACHMENT_TEXTURE2D.rawValue, 0)

    guard rlFramebufferComplete(target.id) else { return }

    rlDisableFramebuffer()
}