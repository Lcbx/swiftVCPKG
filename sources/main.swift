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
        y: Float(raylib.GetRandomValue(0, 25)),
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


var lightCamera = Camera3D(
    position: Vector3(x: -10, y: 60, z: -10),
    target: Vector3(x: 0.0, y: 0.0, z: 0.0),
    up: Vector3(x: 0.0, y: 1.0, z: 0.0),
    fovy: 45.0,
    projection: CAMERA_PERSPECTIVE.rawValue
)

let positions = ecs.list(Position.self)
let velocities = ecs.list(Velocity.self)
let meshes = ecs.list(Mesh.self)


// Load shaders
let depthShader = LoadShaderFromMemory("""
#version 330 core

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec2 vertexTexCoord;
layout(location = 2) in vec3 vertexNormal;

uniform mat4 mvp;

void main()
{
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}


""", """
#version 330 core

layout(location = 0) out vec4 color; 

void main()
{
    //float depth = gl_FragCoord.z;
    //float depth_2 = depth * depth;
    //color = vec4(depth, depth_2, 0.0, 0.0);
    color = vec4(1.0, 0.0, 0.0, 1.0);
}
""")

let sceneShader = LoadShaderFromMemory("""
#version 330 core

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec2 vertexTexCoord;
layout(location = 2) in vec3 vertexNormal;

out vec2 v_TexCoord; //out: vertex shader -> fragment shader
out vec3 v_Normal;
out vec3 v_FragPos;

out vec4 v_FragPosLightSpace;

uniform mat4 matModel;
uniform mat4 matView;
uniform mat4 matProjection;

uniform mat4 u_LightSpaceMatrix;

void main() {
    mat4 MVP = matProjection * matView * matModel;
    gl_Position = MVP * vec4(vertexPosition, 1.0f);
    v_TexCoord = vertexTexCoord;

    v_FragPos = vec3(matModel * vec4(vertexPosition, 1.0f));
    v_Normal = normalize(mat3(transpose(inverse(matModel))) * vertexNormal);
    //camera view space -> light view space
    v_FragPosLightSpace = u_LightSpaceMatrix * vec4(v_FragPos, 1.0f);
};

""", """
#version 330 core

layout(location = 0) out vec4 color; 

in vec2 v_TexCoord;
in vec3 v_FragPos;
in vec3 v_Normal;

in vec4 v_FragPosLightSpace;

struct Material {
    vec3 color; //material color
    float shininess; //maretial softness
};

struct Light {
    float intensity;
    vec3 position; //light position
    vec3 color; //light color

    vec3 ambient; //ambient term
    vec3 diffuse; //diffuse term
    vec3 specular; //specular term
    //Light attenuation
    float kc;
    float kl;
    float kq;
};

uniform Material u_Material;
uniform Light u_Light;


uniform vec3 matViewPos;

uniform sampler2D u_DepthMap; //R: shadow map, G: squared shadow map
uniform sampler2D u_DepthSAT; //SAT map

uniform float u_TextureSize;
uniform float u_LightSize;

uniform int u_ShadowRenderType;


#define EPS 1e-3

#define PI 3.141592653589793
#define PI2 6.283185307179586
#define NUM_RINGS 10

#define NUM_SAMPLES 25 //PCSS sample parameter in step 3
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES //PCSS sample parameter in step 1


/*******-------------------- PCSS functions --------------------******/

highp float rand_1to1(highp float x) {
    // -1 -1
    return fract(sin(x) * 10000.0);
}

highp float rand_2to1(vec2 uv) {
    // 0 - 1
    const highp float a = 12.9898, b = 78.233, c = 43758.5453;
    highp float dt = dot(uv.xy, vec2(a, b)), sn = mod(dt, PI);
    return fract(sin(sn) * c);
}


// poisson distribution
vec2 poissonDisk[NUM_SAMPLES];

void poissonDiskSamples(const in vec2 randomSeed) {

    float ANGLE_STEP = PI2 * float(NUM_RINGS) / float(NUM_SAMPLES);
    float INV_NUM_SAMPLES = 1.0 / float(NUM_SAMPLES);

    float angle = rand_2to1(randomSeed) * PI2;
    float radius = INV_NUM_SAMPLES;
    float radiusStep = radius;

    for (int i = 0; i < NUM_SAMPLES; i++) {
        poissonDisk[i] = vec2(cos(angle), sin(angle)) * pow(radius, 0.75);
        radius += radiusStep;
        angle += ANGLE_STEP;
    }
}

void uniformDiskSamples(const in vec2 randomSeed) {

    float randNum = rand_2to1(randomSeed);
    float sampleX = rand_1to1(randNum);
    float sampleY = rand_1to1(sampleX);

    float angle = sampleX * PI2;
    float radius = sqrt(sampleY);

    for (int i = 0; i < NUM_SAMPLES; i++) {
        poissonDisk[i] = vec2(radius * cos(angle), radius * sin(angle));

        sampleX = rand_1to1(sampleY);
        sampleY = rand_1to1(sampleX);

        angle = sampleX * PI2;
        radius = sqrt(sampleY);
    }
}

/*******-------------------- VSSM functions --------------------******/

//get mean of random 2D area from SAT 
vec4 getMean(float wPenumbra, vec3 projCoords) {

    vec2 stride = 1.0 / vec2(u_TextureSize);

    float xmax = projCoords.x + wPenumbra * stride.x;
    float xmin = projCoords.x - wPenumbra * stride.x;
    float ymax = projCoords.y + wPenumbra * stride.y;
    float ymin = projCoords.y - wPenumbra * stride.y;

    vec4 A = texture(u_DepthSAT, vec2(xmin, ymin));
    vec4 B = texture(u_DepthSAT, vec2(xmax, ymin));
    vec4 C = texture(u_DepthSAT, vec2(xmin, ymax));
    vec4 D = texture(u_DepthSAT, vec2(xmax, ymax));

    float sPenumbra = 2.0 * wPenumbra;

    vec4 moments = (D + A - B - C) / float(sPenumbra * sPenumbra);

    return moments;
}

// Chebychev¡¯s inequality, use to estimate CDF, percentage of non-blockers
// in filter's area
float chebyshev(vec2 moments, float currentDepth) {
    if (currentDepth <= moments.x) {
        return 1.0;
    }
    // calculate variance from mean.
    float variance = moments.y - (moments.x * moments.x);
    variance = max(variance, 0.0001);
    float d = currentDepth - moments.x;
    float p_max = variance / (variance + d * d);
    return p_max;
}

/*******-------------------- PCSS calculation --------------------******/

float PCSS_ShadowCalculation(vec4 fragPosLightSpace, vec3 lightDir)
{
    // Handling Perspective Issues
    vec3 projCoords = fragPosLightSpace.xyz / fragPosLightSpace.w;
    // transform to [0,1] range
    projCoords = projCoords * 0.5 + 0.5;
    // get closest depth value from light's perspective (using [0,1] range fragPosLight as coords)
    float closestDepth = texture(u_DepthMap, projCoords.xy).r;
    
    // get depth of current fragment from light's perspective
    float currentDepth = projCoords.z;
    if (currentDepth > 1.0f) {
        return 1.0f;
    }
    // check whether current frag pos is in shadow
    float bias = max(0.05 * (1.0 - dot(v_Normal, lightDir)), 0.005);
    

    /***--------STEP 1: Blocker search: find the average blocker depth---------***/

    poissonDiskSamples(projCoords.xy); //sampled from poisson distribution

    float sampleStride = u_LightSize/2.5; 
    float dBlocker = 0.0;
    float sampleSize = 1.0 / u_TextureSize * sampleStride;
    int blockerNumSample = BLOCKER_SEARCH_NUM_SAMPLES;

    float border = sampleStride / u_TextureSize;
    // just cut out the no padding area according to the sarched area size
    if (projCoords.x <= border || projCoords.x >= 0.99f - border) {
        return 1.0;
    }
    if (projCoords.y <= border || projCoords.y >= 0.99f - border) {
        return 1.0;
    }

    int count = 0;
    for (int i = 0; i < blockerNumSample; ++i) {
        vec2 sampleCoord = poissonDisk[i] * sampleSize + projCoords.xy;
        float closestDepth = texture(u_DepthMap, sampleCoord).r;
        //Only compute average depth of blocker! not the average of the whole filter's area!
        if (closestDepth < currentDepth) {
            dBlocker += closestDepth;
            count++;
        }
    }
    
    dBlocker /= count;

    if (dBlocker < bias) {
        return 0.0;
    }
    if (dBlocker > 1.0) {
        return 1.0;
    }

    /***---------STEP 02: Penumbra estimation----------***/
    // estimation the filter size to control the softness

    poissonDiskSamples(projCoords.xy); // sampled from poisson distribution

    float lightWidth = u_LightSize/2.5;
    float wPenumbra = (currentDepth - dBlocker) * lightWidth / dBlocker;

    float filterStride = 5.0;
    float filterSize = 1.0 / u_TextureSize * filterStride * wPenumbra;

    /***--------STEP 03: Percentage Closer Filtering (PCF)---------***/

    float shadow = 0.0;
    int NumSample = NUM_SAMPLES;

    for (int i = 0; i < NumSample; ++i) {
        vec2 sampleCoord = poissonDisk[i] * filterSize + projCoords.xy;
        float pcfDepth = texture(u_DepthMap, sampleCoord).r;
        shadow += currentDepth - bias > pcfDepth ? 0.0 : 1.0;
    }
    
    shadow /= NumSample;

    return shadow;
}



/*******-------------------- VSSM calculation --------------------******/

float VSSM_ShadowCalculation(vec4 fragPosLightSpace, vec3 lightDir)
{
    float bias = max(0.005 * (1.0 - dot(v_Normal, lightDir)), 0.005);

    vec3 projCoords = fragPosLightSpace.xyz / fragPosLightSpace.w;
    // transform to [0,1] range
    projCoords = projCoords * 0.5 + 0.5;
    // get closest depth value from light's perspective (using [0,1] range fragPosLight as coords)
    float closestDepth = texture(u_DepthMap, projCoords.xy).r;
    float blockerSearchSize = u_LightSize/2.0f;
    float currentDepth = projCoords.z - bias;
    // keep the shadow at 1.0 when outside the zFar region of the light's frustum.
    if (currentDepth > 1.0) {
        return 1.0f;
    }
    float border = blockerSearchSize / u_TextureSize;
    // just cut out the no padding area according to the sarched area size
    if (projCoords.x <= border || projCoords.x >= 0.99f - border){
        return 1.0;
    }
    if (projCoords.y <= border || projCoords.y >= 0.99f - border) {
        return 1.0;
    }
    // Estimate average blocker depth
    vec4 moments = getMean(float(blockerSearchSize), projCoords);
    //moments.x: store mean of random 2D area of shadow map
    //moments.y: store mean of random 2D area of squared shadow map
    float averageDepth = moments.x;
    float alpha = chebyshev(moments.xy, currentDepth);
    float dBlocker = (averageDepth - alpha * (currentDepth-bias)) / (1.0 - alpha);
    if (dBlocker < EPS) {
        return 0.0;
    }
    if (dBlocker > 1.0) {
        return 1.0;
    }
    float wPenumbra = (currentDepth - dBlocker) * u_LightSize / dBlocker;
    if (wPenumbra <= 0.0) {
        return 1.0;
    }
    moments = getMean(wPenumbra, projCoords);
    if (currentDepth <= moments.x) {
        return 1.0;
    }
    // CDF estimation
    float shadow = chebyshev(moments.xy, currentDepth);
    return shadow;
}



/*******-------------------- PCF calculation --------------------******/
// basic code from learnOpenGL, shadow Chapter.
// Cheack link here https://learnopengl.com/Advanced-Lighting/Shadows/Shadow-Mapping
float PCF_ShadowCalculation(vec4 fragPosLightSpace, vec3 lightDir)
{
    // perform perspective divide
    vec3 projCoords = fragPosLightSpace.xyz / fragPosLightSpace.w;
    // Transform to [0,1] range
    projCoords = projCoords * 0.5 + 0.5;
    // Get closest depth value from light's perspective (using [0,1] range fragPosLight as coords)
    float closestDepth = texture(u_DepthMap, projCoords.xy).r;
    // Get depth of current fragment from light's perspective
    float currentDepth = projCoords.z;
    // Keep the shadow at 0.0 when outside the far_plane region of the light's frustum.
    if (currentDepth > 1.0) {
        return 1.0;
    }
    // Calculate bias (based on depth map resolution and slope)
    float bias = max(0.05 * (1.0 - dot(v_Normal, lightDir)), 0.005);
    // Check whether current frag pos is in shadow
    // float shadow = currentDepth - bias > closestDepth  ? 1.0 : 0.0;
    // PCF
    float shadow = 0.0;
    vec2 texelSize = 1.0 / vec2(u_TextureSize);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            float pcfDepth = texture(u_DepthMap, projCoords.xy + vec2(x, y) * texelSize).r;
            shadow += currentDepth - bias > pcfDepth ? 0.0 : 1.0;
        }
    }
    shadow /= 9.0;
    return shadow;
}


/*******-------------------- Basic calculation --------------------******/
// basic code from learnOpenGL, shadow Chapter.
// Cheack link here https://learnopengl.com/Advanced-Lighting/Shadows/Shadow-Mapping
float Basic_ShadowCalculation(vec4 fragPosLightSpace, vec3 lightDir)
{
    // perform perspective divide
    vec3 projCoords = fragPosLightSpace.xyz / fragPosLightSpace.w;
    // Transform to [0,1] range
    projCoords = projCoords * 0.5 + 0.5;
    // Get closest depth value from light's perspective (using [0,1] range fragPosLight as coords)
    float closestDepth = texture(u_DepthMap, projCoords.xy).r;
    // Get depth of current fragment from light's perspective
    float currentDepth = projCoords.z;
    // Keep the shadow at 0.0 when outside the far_plane region of the light's frustum.
    if (currentDepth > 1.0) {
        return 1.0;
    }
    // Calculate bias (based on depth map resolution and slope)
    float bias = max(0.05 * (1.0 - dot(v_Normal, lightDir)), 0.005);
    // Check whether current frag pos is in shadow
    float shadow = currentDepth - bias > closestDepth  ? 0.0 : 1.0;
    return shadow;
}


//**-----main function------**/
void main() {
    
    //Blinn-Phong

    //calculate attenuation
    vec3 actualLight = u_Light.position - v_FragPos; //actual light (Opposite direction)
    float distance = length(actualLight); //light length
    float attenuation = 1.0f / (u_Light.kc + u_Light.kl * distance + u_Light.kq * distance * distance); //¼ÆËãË¥¼õ

    //ambient 
    vec3 ambient = u_Material.color * u_Light.color * u_Light.ambient;
    ambient = u_Light.intensity * ambient;

    //diffuse
    vec3 lightDir = normalize(actualLight);
    float diff = max(dot(lightDir, v_Normal), 0.0f);
    vec3 diffuse = u_Material.color * u_Light.color * u_Light.diffuse * diff;
    diffuse = u_Light.intensity * diffuse;

    //specular
    vec3 viewDir = normalize(matViewPos - v_FragPos);
    vec3 halfwayDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(halfwayDir, v_Normal), 0.0f), u_Material.shininess);
    vec3 specular = u_Material.color * u_Light.color * u_Light.specular * spec;
    specular = u_Light.intensity * specular;

    //calculate shadow
    float shadow = 1.0f;
    if (u_ShadowRenderType == 0) {
        shadow = Basic_ShadowCalculation(v_FragPosLightSpace, lightDir);
    }
    else if (u_ShadowRenderType == 1) {
        shadow = PCF_ShadowCalculation(v_FragPosLightSpace, lightDir);
    }
    else if(u_ShadowRenderType == 2){
        shadow = PCSS_ShadowCalculation(v_FragPosLightSpace, lightDir);
    }
    else if (u_ShadowRenderType == 3) {
        shadow = VSSM_ShadowCalculation(v_FragPosLightSpace, lightDir);
    }
    vec3 lighting = (ambient + shadow * (diffuse + specular)) * attenuation;
    //gammar ajust
    //lighting = pow(lighting, vec3(1 / 2.2));

    color = vec4(lighting, 1.0f);
};
""")

// Create render texture for shadow map
let shadowMapSize: Int32 = 1024
let shadowMap = CreateShadowTexture(shadowMapSize, shadowMapSize)!

// Shader uniforms
let sceneLightMatrixLoc = GetShaderLocation(sceneShader, "u_LightSpaceMatrix")
let sceneDepthMapLoc = GetShaderLocation(sceneShader, "u_DepthMap")

// ground
let planeMesh = GenMeshPlane(25.0, 25.0, 1, 1)
let planeModel = LoadModelFromMesh(planeMesh)


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


    // shadows
    BeginTextureMode(shadowMap)
    ClearBackground(RAYBLACK)
    BeginMode3D(lightCamera)
    BeginShaderMode(depthShader)

    let lightProj = rlGetMatrixProjection()
    let lightView = rlGetMatrixModelview()
    let lightSpaceMatrix = MatrixMultiply(lightProj, lightView)
    
    //planeModel.materials[0].shader = depthShader
    
    drawScene()

    EndShaderMode()
    EndMode3D()
    EndTextureMode()


    // main scene
    raylib.BeginMode3D(camera)
    //BeginShaderMode(sceneShader)

    var slot = 10; // Can be anything 0 to 15, but 0 will probably be taken up
    rlActiveTextureSlot(10);
    rlEnableTexture(shadowMap.depth.id);
    rlSetUniform(sceneDepthMapLoc, &slot, SHADER_UNIFORM_INT.rawValue, 1);

    SetShaderValueMatrix(sceneShader, sceneLightMatrixLoc, lightSpaceMatrix)
    //SetShaderValueTexture(sceneShader, sceneDepthMapLoc, shadowMap.texture)
    SetShaderValue(sceneShader, GetShaderLocation(sceneShader, "u_Light.intensity"), [1.0], 1)
    SetShaderValue(sceneShader, GetShaderLocation(sceneShader, "u_Light.position"), [lightCamera.position], 3)
    SetShaderValue(sceneShader, GetShaderLocation(sceneShader, "u_Light.color"), [RAYWHITE], 3)
    SetShaderValue(sceneShader, GetShaderLocation(sceneShader, "u_Light.ambient"), [RAYWHITE], 3)
    SetShaderValue(sceneShader, GetShaderLocation(sceneShader, "u_Light.diffuse"), [RAYWHITE], 3)
    SetShaderValue(sceneShader, GetShaderLocation(sceneShader, "u_Light.specular"), [RAYWHITE], 3)
    SetShaderValue(sceneShader, GetShaderLocation(sceneShader, "u_Light.kc"), [1.0], 1)
    SetShaderValue(sceneShader, GetShaderLocation(sceneShader, "u_Light.kl"), [0.09], 1)
    SetShaderValue(sceneShader, GetShaderLocation(sceneShader, "u_Light.kq"), [0.032], 1)

    // Material parameters
    SetShaderValue(sceneShader, GetShaderLocation(sceneShader, "u_Material.color"), [LIGHTGRAY], 3)
    SetShaderValue(sceneShader, GetShaderLocation(sceneShader, "u_Material.shininess"), [0.5], 1)

    // Shadow parameters
    SetShaderValue(sceneShader, GetShaderLocation(sceneShader, "u_ShadowRenderType"), [Int32(1)], 1)
    SetShaderValue(sceneShader, GetShaderLocation(sceneShader, "u_TextureSize"), [Float(shadowMapSize)], 1)
    SetShaderValue(sceneShader, GetShaderLocation(sceneShader, "u_LightSize"), [Float(50)], 1)


    planeModel.materials[0].shader = sceneShader
    
    drawScene()

    //EndShaderMode()
    raylib.EndMode3D()

    positions.upkeep()                                                                                       
    velocities.upkeep()                                                                                      
    meshes.upkeep()
}
raylib.CloseWindow()

func drawScene(){
    DrawModel(planeModel, Vector3(x: 0, y: -1, z: 0), 3.5, LIGHTGRAY)

    //NOTE: drawing must be on main thread
    var frustum = createFrustum()
    for (pos, mesh) in ecs.iterate(positions, meshes) {
        let bb = mesh.boundingBox
        let bbCenter = raylib.Vector3Lerp(bb.min, bb.max, 0.5)
        let bbSize = raylib.Vector3Subtract(bb.max, bb.min)
        let transform = raylib.MatrixTranslate(pos.x,pos.y,pos.z)
        let position = raylib.Vector3Transform(bbCenter, transform)

        guard frustumFilter(frustum,bb,transform) else { continue }
        raylib.DrawCube(position, bbSize.x, bbSize.y, bbSize.z, mesh.color)
    }
}



func CreateShadowTexture(_ width: Int32, _ height: Int32) -> RenderTexture2D? {
    var target = RenderTexture2D()

    target.id = rlLoadFramebuffer() // Load an empty framebuffer
    target.texture.width = width
    target.texture.height = height


    guard target.id > 0 else { return nil }
    rlEnableFramebuffer(target.id)

    // Create depth texture
    target.depth.id = rlLoadTextureDepth(width, height, false) // useRenderBuffer = false
    target.depth.width = width
    target.depth.height = height
    target.depth.format = 19 // DEPTH_COMPONENT_24BIT
    target.depth.mipmaps = 1

    // Attach depth texture to FBO
    rlFramebufferAttach(target.id, target.depth.id, RL_ATTACHMENT_DEPTH.rawValue, RL_ATTACHMENT_TEXTURE2D.rawValue, 0)

    guard rlFramebufferComplete(target.id) else { return nil }

    rlDisableFramebuffer()
    
    print("created shadowmap")
    return target
}

func unloadRenderTexture(_ target: RenderTexture2D) {
    if target.id > 0 {
        rlUnloadFramebuffer(target.id)
    }
}