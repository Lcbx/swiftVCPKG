

// identifier for entities
typealias Entity = Int
let EMPTY = Entity.max

typealias TypeId = ObjectIdentifier

// TypeId is always the same
// ComponentId is specific to an ECScene
typealias ComponentId = UInt
// we consider that either the entity just got created or got deleted
// we might lose entities if people delete all components of an entity before deleting it
let DELETED : ComponentId = 0


// Componentmask is one-hot encoded ComponentId
typealias ComponentMask = UInt
protocol Component {
    static var typeId : TypeId { get set }
}