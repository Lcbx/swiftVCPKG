import Foundation
import raylib



typealias Color = raylib.Color
typealias Vec2 = raylib.Vector2

let rnd_uint8 = { return UInt8(raylib.GetRandomValue(0, 255)) }
let rnd_color = { return Color(r: rnd_uint8(), g: rnd_uint8(), b: rnd_uint8(), a: 255) }

let RAYWHITE = Color(r:255,g:255,b:255,a:255)
let LIGHTGRAY = Color(r:100,g:0,b:100,a:255)

let WINDOW_SIZE = Vec2(x:800, y:400)

raylib.InitWindow(Int32(WINDOW_SIZE.x), Int32(WINDOW_SIZE.y), "hello world")
raylib.SetTargetFPS(60)

/// SOOOOO...
/// classes are slowest, struct are better, and tuple of all components is fastest...
/// maybe add container for tuples of associated structs instead of just foreach

let SQUARE_N = 30000

struct Position {
//class Position {
//    public init(pos:Vec2){self.pos = pos}
    public var pos : Vec2
}
struct Velocity {
//class Velocity {
//    public init(vel:Vec2){self.vel = vel}
    public var vel : Vec2
}

var ecs = EntityComponentSystem();
let posId = ecs.getComponentId(Position.self)
let velId = ecs.getComponentId(Velocity.self)
let colId = ecs.getComponentId(Color.self)
ecs.CreateEntities(SQUARE_N)

typealias Square = (pos : Vec2, vel: Vec2, color: Color)
var squares = [Square]()

for i in 0..<SQUARE_N{
    
    // squares.append(Square(
    //    pos:Vec2(x:Float(i)*WINDOW_SIZE.x/Float(SQUARE_N),y:WINDOW_SIZE.y/Float(2)),
    //    vel:Vec2(x:Float(rnd_uint8())/255.0,y:Float(rnd_uint8())/255.0),
    //    color:rnd_color()))
    
    ecs.addComponentFast(Position(pos: Vec2(x:Float(i)*WINDOW_SIZE.x/Float(SQUARE_N),y:WINDOW_SIZE.y/Float(2))), componentId:posId, entity:i)
    ecs.addComponentFast(Velocity(vel: Vec2(x:Float(rnd_uint8())/255.0,y:Float(rnd_uint8())/255.0)), componentId:velId, entity:i)
    ecs.addComponentFast(rnd_color(), componentId:colId, entity:i)
}

while !raylib.WindowShouldClose()
{
    //let time = raylib.GetTime()
    raylib.BeginDrawing()
        raylib.ClearBackground(RAYWHITE)
        raylib.DrawText("\(raylib.GetFPS())", 10, 10, 20, LIGHTGRAY)

        for (_, pos, col) in ecs.ForEach(Position.self, Color.self) {
            DrawRectangleV(pos.pos, Vec2(x:10,y:10), col);
        }

        // TODO: find a better way to edit components
        // maybe make ForEach return the index in storage since that's nore relevant than entity's id
        var positions = ecs.ForEach(Position.self)
        var velocities = ecs.ForEach(Velocity.self)
        var i = 0
        var j = 0
        for (entity, var pos, var vel) in ecs.ForEach(Position.self, Velocity.self) {
            while positions[i].entity != entity{
                i+=1
            }
            while velocities[j].entity != entity{
                j+=1
            }
            pos.pos += vel.vel

            if pos.pos.x < 0 { pos.pos.x = 0; vel.vel.x = -vel.vel.x }
            if pos.pos.y < 0 { pos.pos.y = 0; vel.vel.y = -vel.vel.y }
            if pos.pos.x > WINDOW_SIZE.x { pos.pos.x = WINDOW_SIZE.x; vel.vel.x = -vel.vel.x }
            if pos.pos.y > WINDOW_SIZE.y { pos.pos.y = WINDOW_SIZE.y; vel.vel.y = -vel.vel.y }
            
            positions[i] = (entity, pos)
            velocities[j] = (entity, vel)
        }
        ecs.storages[posId] = positions
        ecs.storages[velId] = velocities

        // for (i, var square) in squares.enumerated(){
        //    DrawRectangleV(square.pos, Vec2(x:10,y:10), square.color);
        //    square.pos += square.vel
        //    if square.pos.x < 0 { square.pos.x = 0; square.vel.x = -square.vel.x }
        //    if square.pos.y < 0 { square.pos.y = 0; square.vel.y = -square.vel.y }
        //    if square.pos.x > WINDOW_SIZE.x { square.pos.x = WINDOW_SIZE.x; square.vel.x = -square.vel.x }
        //    if square.pos.y > WINDOW_SIZE.y { square.pos.y = WINDOW_SIZE.y; square.vel.y = -square.vel.y }
        //    squares[i] = square
        // }


    raylib.EndDrawing()
}
raylib.CloseWindow()