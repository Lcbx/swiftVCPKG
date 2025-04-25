import Foundation
import raylib

// pipe operator
// baz |> bar |> foo is equivalent to foo(bar(baz)
infix operator |> : AdditionPrecedence
func |> <T,U>(value:T, function: (T)->U) -> U { return function(value) }


// simple task system where tasks are all in same DispatchGroup
let Tasks = DispatchGroup()
func RunTask( task : @escaping () -> Void) {
	Tasks.enter()
	DispatchQueue.global(qos: .default).async { 
	    task()
	    Tasks.leave()
	}
}

extension Array {
	func parallelFor(execute action : (Element) -> Void ){
		DispatchQueue.concurrentPerform( iterations:self.count ){ i in
			action( self[i] )
		}
	}
}



typealias Vec2 = raylib.Vector2
typealias Vec3 = raylib.Vector3
typealias Vec4 = raylib.Vector4

let rnd_uint8 = { return UInt8(raylib.GetRandomValue(0, 255)) }
let rnd_color = { return raylib.Color(r: rnd_uint8(), g: rnd_uint8(), b: rnd_uint8(), a: 255) }

let RAYWHITE = raylib.Color(r:255,g:255,b:255,a:255)
let RAYBLACK = raylib.Color(r:0,g:0,b:0,a:255)
let LIGHTGRAY = raylib.Color(r:100,g:100,b:100,a:255)