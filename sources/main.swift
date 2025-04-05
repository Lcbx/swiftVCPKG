import Foundation
import raylib

let RAYWHITE = raylib.Color(r:255,g:255,b:255,a:255)
let LIGHTGRAY = raylib.Color(r:100,g:0,b:100,a:255)

raylib.InitWindow(800, 450, "hello world")
raylib.SetTargetFPS(60)

while !raylib.WindowShouldClose()
{
    let time = raylib.GetTime()
    raylib.BeginDrawing()
        raylib.ClearBackground(RAYWHITE)
        raylib.DrawText("\(raylib.GetFPS())", 10, 10, 20, LIGHTGRAY)
        raylib.DrawText("Congrats! You created your first window!",
            Int32(cos(time) * 50) + 190,
            Int32(sin(time) * 50) + 200, 20,
            LIGHTGRAY)
    raylib.EndDrawing()
}
raylib.CloseWindow()