

// identifier for entities
typealias Entity = Int
let EMPTY = Entity.max

// TypeId is type always the same while ComponentId is specific to an ECScene
typealias ComponentId = Int
typealias TypeId = ObjectIdentifier

// Componentmask is one-hot encoded ComponentId
typealias ComponentMask = UInt

protocol Component {
    static var typeId : TypeId { get set }
}