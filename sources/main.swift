import Foundation
import raylib



typealias Vec2 = raylib.Vector2
let rnd_uint8 = { return UInt8(raylib.GetRandomValue(0, 255)) }
let rnd_color = { return raylib.Color(r: rnd_uint8(), g: rnd_uint8(), b: rnd_uint8(), a: 255) }

let RAYWHITE = raylib.Color(r:255,g:255,b:255,a:255)
let LIGHTGRAY = raylib.Color(r:100,g:0,b:100,a:255)

let WINDOW_SIZE = Vec2(x:800, y:400)

raylib.InitWindow(Int32(WINDOW_SIZE.x), Int32(WINDOW_SIZE.y), "hello world")
raylib.SetTargetFPS(60)

/// SOOOOO...
/// classes are slowest, struct are better, and tuple of all components is fastest...
/// maybe add container for tuples of associated structs instead of just foreach

let SQUARE_N = 30000

struct Position : Component {
    static var componentId = -1
    public var x : Float
    public var y : Float
}
struct Velocity : Component {
    static var componentId = -1
    public var x : Float
    public var y : Float
}

struct Color : Component{
    static var componentId = -1
    public var data : raylib.Color
}

var ecs = EntityComponentSystem();
ecs.addComponentType(Position.self)
ecs.addComponentType(Velocity.self)
ecs.addComponentType(Color.self)
ecs.CreateEntities(SQUARE_N/2)
ecs.CreateEntities(SQUARE_N/2)

typealias Square = (pos : Vec2, vel: Vec2, color: raylib.Color)
var squares = [Square]()

for i in 0..<SQUARE_N{
    
     squares.append(Square(
        pos:Vec2(x:Float(i)*WINDOW_SIZE.x/Float(SQUARE_N),y:WINDOW_SIZE.y/Float(2)),
        vel:Vec2(x:Float(rnd_uint8())/255.0,y:Float(rnd_uint8())/255.0),
        color:rnd_color()))
    
    ecs.addComponent(Position(x:Float(i)*WINDOW_SIZE.x/Float(SQUARE_N),y:WINDOW_SIZE.y/Float(2)), entity:i)
    ecs.addComponent(Velocity(x:Float(rnd_uint8())/255.0,y:Float(rnd_uint8())/255.0), entity:i)
    ecs.addComponent(Color(data:rnd_color()), entity:i)
}

while !raylib.WindowShouldClose()
{
    //let time = raylib.GetTime()
    raylib.BeginDrawing()
        raylib.ClearBackground(RAYWHITE)
        raylib.DrawText("\(raylib.GetFPS())", 10, 10, 20, LIGHTGRAY)

        for (_, pos, col) in ecs.ForEach(Position.self, Color.self) {
           DrawRectangle(Int32(pos.x), Int32(pos.y), 10, 10, col.data);
        }

        // TODO: find a better way to edit components
        // maybe make ForEach return the index in storage since that's nore relevant than entity's id
        let positions = ecs.ForEach(Position.self)
        let velocities = ecs.ForEach(Velocity.self)
        for (entity, var pos, var vel) in ecs.ForEach(Position.self, Velocity.self) {
           pos.x += vel.x
           pos.y += vel.y
           positions.set((entity, pos))

           if pos.x < 0 { pos.x = 0; vel.x = -vel.x }
           if pos.y < 0 { pos.y = 0; vel.y = -vel.y }
           if pos.x > WINDOW_SIZE.x { pos.x = WINDOW_SIZE.x; vel.x = -vel.x }
           if pos.y > WINDOW_SIZE.y { pos.y = WINDOW_SIZE.y; vel.y = -vel.y }
            
           velocities.set((entity, vel))
        }

          // for (i, var square) in squares.enumerated(){
             // DrawRectangleV(square.pos, Vec2(x:10,y:10), square.color);
             // square.pos += square.vel
             // if square.pos.x < 0 { square.pos.x = 0; square.vel.x = -square.vel.x }
             // if square.pos.y < 0 { square.pos.y = 0; square.vel.y = -square.vel.y }
             // if square.pos.x > WINDOW_SIZE.x { square.pos.x = WINDOW_SIZE.x; square.vel.x = -square.vel.x }
             // if square.pos.y > WINDOW_SIZE.y { square.pos.y = WINDOW_SIZE.y; square.vel.y = -square.vel.y }
             // squares[i] = square
          // }


    raylib.EndDrawing()
}
raylib.CloseWindow()