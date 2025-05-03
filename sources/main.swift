import Foundation
import raylib
import raygui
import pocketpy

#if DEBUG
    print("Debug")
#else
    print("Release")
#endif


let WINDOW_SIZE = Vec2(x:1800, y:900)
let middle = Vec2(x:WINDOW_SIZE.x/2, y:WINDOW_SIZE.y/2)

let scale = WINDOW_SIZE.x / 100
let fontSize = Int32(7+1.5*scale)

InitWindow(Int32(WINDOW_SIZE.x), Int32(WINDOW_SIZE.y), "swift raylib experiments")
SetTargetFPS(30)
GuiSetStyle(DEFAULT.rawValue, TEXT_SIZE.rawValue, fontSize)

while !WindowShouldClose()
{
	BeginDrawing()
	defer {
		DrawText("\(GetFPS())", 10, 10, fontSize, LIGHTGRAY)
		DrawText("welcome", 10, 30, fontSize, LIGHTGRAY)
		EndDrawing()
	}

	ClearBackground(RAYWHITE)
	if GuiButton(Rectangle( x:middle.x-15*scale, y:middle.y-4*scale, width:30*scale, height:4*scale ),
		"Frustum culling example") != 0 { FrustumTest() }
	if GuiButton(Rectangle( x:middle.x-15*scale, y:middle.y+4*scale, width:30*scale, height:4*scale ),
		"ShadowMap example") != 0 { ShadowMapTest() }
}

