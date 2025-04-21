import Foundation
import raylib

#if DEBUG
    print("Debug")
#else
    print("Release")
#endif


typealias Vec2 = raylib.Vector2
let rnd_uint8 = { return UInt8(raylib.GetRandomValue(0, 255)) }
let rnd_color = { return raylib.Color(r: rnd_uint8(), g: rnd_uint8(), b: rnd_uint8(), a: 255) }

let RAYWHITE = raylib.Color(r:255,g:255,b:255,a:255)
let LIGHTGRAY = raylib.Color(r:100,g:100,b:100,a:255)

let WINDOW_SIZE = Vec2(x:800, y:400)

raylib.InitWindow(Int32(WINDOW_SIZE.x), Int32(WINDOW_SIZE.y), "hello world")
raylib.SetTargetFPS(60)

let SQUARE_N = 30000

struct Position : Component {
    static var typeId = TypeId(Self.self)
    public var x : Float
    public var y : Float
}
struct Velocity : Component {
    static var typeId = TypeId(Self.self)
    public var x : Float
    public var y : Float
}

struct Color : Component{
    static var typeId = TypeId(Self.self)
    public var data : raylib.Color
}

var ecs = ECScene();

ecs.Component(Position.self)
ecs.Component(Velocity.self)
ecs.Component(Color.self)

typealias Square = (pos : Vec2, vel: Vec2, color: raylib.Color)
var squares = [Square]()

let _ = ecs.createEntities(1)

for i in ecs.createEntities(SQUARE_N){
     // squares.append(Square(
     //    pos:Vec2(x:Float(i)*WINDOW_SIZE.x/Float(SQUARE_N),y:WINDOW_SIZE.y/Float(2)),
     //    vel:Vec2(x:Float(rnd_uint8())/255.0,y:Float(rnd_uint8())/255.0),
     //    color:rnd_color()))
    
    let entityProxy = ecs[i]
    entityProxy.add(Position(x:Float(i)*WINDOW_SIZE.x/Float(SQUARE_N),y:WINDOW_SIZE.y/Float(2)))
    entityProxy.add(Velocity(x:Float(rnd_uint8())/255.0,y:Float(rnd_uint8())/255.0))
    entityProxy.add(Color(data:rnd_color()))
}


let positions = ecs.list(Position.self)
let velocities = ecs.list(Velocity.self)
let colors = ecs.list(Color.self)

let dispatchGroup = DispatchGroup()

var showMessageBox = true

while !raylib.WindowShouldClose()
{
    //let time = raylib.GetTime()
    raylib.BeginDrawing()
    repeat {
        raylib.ClearBackground(RAYWHITE)
        defer { raylib.DrawText("\(raylib.GetFPS())", 10, 10, 20, LIGHTGRAY)}

        dispatchGroup.enter()
        DispatchQueue.global(qos: .default).async { 
            for(entity, var p, var v) in ecs.iterateWithEntity(positions, velocities) {
                p.x += v.x                                                                                       
                p.y += v.y                                                                                       
                if p.x < 0 { p.x = 0; v.x = -v.x }                                                               
                if p.y < 0 { p.y = 0; v.y = -v.y }                                                               
                if p.x > WINDOW_SIZE.x { p.x = WINDOW_SIZE.x; v.x = -v.x }                                       
                if p.y > WINDOW_SIZE.y { p.y = WINDOW_SIZE.y; v.y = -v.y }                                       
                positions[entity] = p                                                                            
                velocities[entity] = v  
            }
            dispatchGroup.leave()
        }
        //NOTE: drawing must be on main thread
        for (pos, col) in ecs.iterate(positions, colors) {
           DrawRectangleV(Vec2(x:pos.x, y:pos.y), Vec2(x:10,y:10), col.data);
        }
        dispatchGroup.wait()

        for (entity, _) in positions.iterateWithEntity().prefix(20){
            ecs.deleteEntity(entity)
        }

        if raylib.GuiButton(raylib.Rectangle(x:24,y:24,width:120,height:30), "#191#Show Message") != 0 {
            showMessageBox = true
        }

        if showMessageBox
        {
            let result = raylib.GuiMessageBox(raylib.Rectangle(x:85,y:70,width:250,height:100),
                "#191#Message Box", "Hi! This is a message!", "Nice;Cool");

            if result >= 0 {
                showMessageBox = false
            }
        }

        positions.upkeep()                                                                                       
        velocities.upkeep()                                                                                      
        colors.upkeep() 

      // for (i, var square) in squares.enumerated(){
      //    DrawRectangleV(square.pos, Vec2(x:10,y:10), square.color);
      //    square.pos += square.vel
      //    if square.pos.x < 0 { square.pos.x = 0; square.vel.x = -square.vel.x }
      //    if square.pos.y < 0 { square.pos.y = 0; square.vel.y = -square.vel.y }
      //    if square.pos.x > WINDOW_SIZE.x { square.pos.x = WINDOW_SIZE.x; square.vel.x = -square.vel.x }
      //    if square.pos.y > WINDOW_SIZE.y { square.pos.y = WINDOW_SIZE.y; square.vel.y = -square.vel.y }
      //    squares[i] = square
      // }

    } while false
    raylib.EndDrawing()
}
raylib.CloseWindow()
