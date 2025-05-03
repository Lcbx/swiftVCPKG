import Foundation
import raylib

func ShadowMapTest(){

	SetWindowTitle("Shadow map example"); 
	SetTargetFPS(60)


	let SQUARE_N : Int = 15
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

	let positions = ecs.list(Position.self)
	let velocities = ecs.list(Velocity.self)
	let meshes = ecs.list(Mesh.self)

	let blackBar = ecs[ecs.createEntities(1).first!]
	blackBar.add(Position(x: 0, y: -1, z: 0))
	blackBar.add(Mesh(color:BLACK,
		boundingBox:BoundingBox(
		min: Vec3(x:-0.5, y:-20, z:-0.5),
		max: Vec3(x:0.5, y:20, z:0.5))
	))


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
		target: Vec3(x:0, y:0, z:0),
		up: Vec3(x: 0, y: 1, z: 0),
		fovy: 60.0,
		projection: CAMERA_PERSPECTIVE.rawValue
	)


	var lightCamera = Camera3D(
		position: Vec3(x: -10, y: 50, z: 10),
		target: Vec3(x: 0, y: 0, z: 0),
		up: Vec3(x: 0, y: 1, z: 0),
		fovy: 90.0,
		projection: CAMERA_ORTHOGRAPHIC.rawValue
	)


	// Load shaders
	//let sceneShader = LoadShaderFromMemory("""vs""", """fs""")
	let shader_root = "../sources/rendering/shaders/"
	var sceneShader : Shader

	var shadowmap = shadowBuffer(1024,1024,colorBufferFormat:PIXELFORMAT_UNCOMPRESSED_R32)
	GenTextureMipmaps(&shadowmap.texture);
	GenTextureMipmaps(&shadowmap.depth);
	SetTextureFilter(shadowmap.texture, TEXTURE_FILTER_TRILINEAR.rawValue);
	SetTextureFilter(shadowmap.depth, TEXTURE_FILTER_TRILINEAR.rawValue);
	var shadowShader : Shader

		
	func LoadShaders() -> (Shader, Shader){
		(
			LoadShader(shader_root + "lightmap.vs", shader_root + "lightmap.fs"),
			LoadShader(shader_root + "shadow.vs", shader_root + "shadow.fs"),
		)
	}

	(sceneShader, shadowShader) = LoadShaders()
	 
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
				let newShaders = LoadShaders()
				guard newShaders.0.id > 0 && newShaders.1.id > 0 else { return }
				sceneShader = newShaders.0
				shadowShader = newShaders.1
			}()
		}
		if IsKeyPressed(KEY_P.rawValue){
			lightCamera.projection = (
				lightCamera.projection == CAMERA_PERSPECTIVE.rawValue ?
				CAMERA_ORTHOGRAPHIC.rawValue : CAMERA_PERSPECTIVE.rawValue
			)
		}
		let scrollspeed = Float(3.0);
		let mw = scrollspeed * GetMouseWheelMove()
		if camera.position.y > scrollspeed + 0.5 || mw > 0.0 {
			camera.position = Vector3Add(camera.position, Vector3Multiply(Vector3Normalize(Vec3(x:24, y: 70, z: -24)), Vec3(x:mw,y:mw,z:mw)))
		}
		
		
		BeginDrawing()
		
		var lightNearFar = Vec2(x:5,y:100)
		BeginTextureMode(shadowmap)
		rlSetClipPlanes(Double(lightNearFar.x), Double(lightNearFar.y))
		BeginMode3D(lightCamera)
			BeginShaderMode(shadowShader)
			ClearBackground(RAYWHITE)
			rlSetCullFace(RL_CULL_FACE_FRONT.rawValue)
			
			let lightVP = MatrixMultiply(rlGetMatrixModelview(), rlGetMatrixProjection())
			var lightDir = Vector3Normalize(Vector3Subtract(lightCamera.target, lightCamera.position))
		
			drawScene()
			
			rlSetCullFace(RL_CULL_FACE_BACK.rawValue)
			EndShaderMode()
		EndMode3D()
		EndTextureMode()
		
		// avoid spam
		SetTraceLogLevel(LOG_WARNING.rawValue)
		GenTextureMipmaps(&shadowmap.texture);
		GenTextureMipmaps(&shadowmap.depth);
		SetTraceLogLevel(LOG_INFO.rawValue)

		defer {
			DrawText("\(GetFPS())", 10, 10, 20, LIGHTGRAY)
			DrawText("press R to reload shaders, P to toggle light type (directional/spot)", 10, 30, 20, LIGHTGRAY) 
			drawshadowmap()
			EndDrawing()
		}
		
		rlSetClipPlanes(0.01, 1000)
		BeginMode3D(camera)
			ClearBackground(RAYWHITE)
			DrawGrid(25, 2.0)
		
			DrawSphere(lightCamera.position, 0.6, Color(r: 200, g: 100, b: 0, a: 255))
			DrawLine3D(lightCamera.position, lightCamera.target, Color(r: 250, g: 50, b: 30, a: 255))
			
			BeginShaderMode(sceneShader)
			
			SetShaderValue(sceneShader,GetShaderLocation(shadowShader,"lightDir"),&lightDir, SHADER_UNIFORM_VEC3.rawValue)
			SetShaderValue(sceneShader,GetShaderLocation(sceneShader,"lightDir"),&lightDir, SHADER_UNIFORM_VEC3.rawValue)
			SetShaderValueMatrix(sceneShader,GetShaderLocation(sceneShader,"lightVP"),lightVP)
			SetShaderValueTexture(sceneShader,GetShaderLocation(sceneShader,"texture_shadowmap"),shadowmap.depth)
			SetShaderValueTexture(sceneShader,GetShaderLocation(sceneShader,"texture_shadowmap2"),shadowmap.texture)
			
			drawScene()
			
			EndShaderMode()
		EndMode3D()

		positions.upkeep()                                                                                       
		velocities.upkeep()                                                                                      
		meshes.upkeep()
	}
	CloseWindow()

	func drawScene(){
		// ground
		DrawCube(Vec3(x: 0, y: -0.51, z: 0), 50, 1, 50, LIGHTGRAY)

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

	/*
	typedef enum {
		RL_PIXELFORMAT_UNCOMPRESSED_GRAYSCALE = 1,     // 8 bit per pixel (no alpha)
		RL_PIXELFORMAT_UNCOMPRESSED_GRAY_ALPHA,        // 8*2 bpp (2 channels)
		RL_PIXELFORMAT_UNCOMPRESSED_R5G6B5,            // 16 bpp
		RL_PIXELFORMAT_UNCOMPRESSED_R8G8B8,            // 24 bpp
		RL_PIXELFORMAT_UNCOMPRESSED_R5G5B5A1,          // 16 bpp (1 bit alpha)
		RL_PIXELFORMAT_UNCOMPRESSED_R4G4B4A4,          // 16 bpp (4 bit alpha)
		RL_PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,          // 32 bpp
		RL_PIXELFORMAT_UNCOMPRESSED_R32,               // 32 bpp (1 channel - float)
		RL_PIXELFORMAT_UNCOMPRESSED_R32G32B32,         // 32*3 bpp (3 channels - float)
		RL_PIXELFORMAT_UNCOMPRESSED_R32G32B32A32,      // 32*4 bpp (4 channels - float)
		RL_PIXELFORMAT_UNCOMPRESSED_R16,               // 16 bpp (1 channel - half float)
		RL_PIXELFORMAT_UNCOMPRESSED_R16G16B16,         // 16*3 bpp (3 channels - half float)
		RL_PIXELFORMAT_UNCOMPRESSED_R16G16B16A16,      // 16*4 bpp (4 channels - half float)
		RL_PIXELFORMAT_COMPRESSED_DXT1_RGB,            // 4 bpp (no alpha)
		RL_PIXELFORMAT_COMPRESSED_DXT1_RGBA,           // 4 bpp (1 bit alpha)
		RL_PIXELFORMAT_COMPRESSED_DXT3_RGBA,           // 8 bpp
		RL_PIXELFORMAT_COMPRESSED_DXT5_RGBA,           // 8 bpp
		RL_PIXELFORMAT_COMPRESSED_ETC1_RGB,            // 4 bpp
		RL_PIXELFORMAT_COMPRESSED_ETC2_RGB,            // 4 bpp
		RL_PIXELFORMAT_COMPRESSED_ETC2_EAC_RGBA,       // 8 bpp
		RL_PIXELFORMAT_COMPRESSED_PVRT_RGB,            // 4 bpp
		RL_PIXELFORMAT_COMPRESSED_PVRT_RGBA,           // 4 bpp
		RL_PIXELFORMAT_COMPRESSED_ASTC_4x4_RGBA,       // 8 bpp
		RL_PIXELFORMAT_COMPRESSED_ASTC_8x8_RGBA        // 2 bpp
	} rlPixelFormat;
	*/
	func shadowBuffer(_ width : Int32, _ height:Int32, colorBufferFormat:PixelFormat?=nil) -> RenderTexture2D {
		//var target = LoadRenderTexture(width, height)
		var target = RenderTexture2D()
		target.id = rlLoadFramebuffer()
		
		if target.id > 0 {
			rlEnableFramebuffer(target.id)
			target.texture.width = width
			target.texture.height = height
			
			if let colorFormat = colorBufferFormat {
				target.texture.format = colorFormat.rawValue
				target.texture.mipmaps = 1
				target.texture.id = rlLoadTexture(nil, width, height, colorFormat.rawValue, target.texture.mipmaps)
				rlFramebufferAttach(target.id, target.texture.id, RL_ATTACHMENT_COLOR_CHANNEL0.rawValue, RL_ATTACHMENT_TEXTURE2D.rawValue, 0)
			}

			target.depth.id = rlLoadTextureDepth(width, height, false)
			target.depth.width = width
			target.depth.height = height
			target.depth.format = PIXELFORMAT_UNCOMPRESSED_R32.rawValue
			target.depth.mipmaps = 1

			rlFramebufferAttach(target.id, target.depth.id, RL_ATTACHMENT_DEPTH.rawValue, RL_ATTACHMENT_TEXTURE2D.rawValue, 0)

			rlDisableFramebuffer()
		}   
		return target
	}

}