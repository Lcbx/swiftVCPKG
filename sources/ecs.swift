typealias Entity = Int
typealias ComponentId = Int
typealias ComponentMask = Int


protocol Component {
    static var componentId : ComponentId {get set}
}

typealias ComponentEntry<T : Component> = (entity:Entity, component:T)

protocol ComponentStorage {
    func setEntityCount(_ count :Int)
}

class ComponentSet<T : Component> : ComponentStorage {
    public var sparse = [Entity]()
    public var dense = [ComponentEntry<T>]()

    public init(){
        dense.reserveCapacity(512)
    }

    public func add(_ ce : ComponentEntry<T> ){
        sparse[ce.entity] = dense.count
        dense.append(ce)
    }

    public func setEntityCount(_ count :Int){
        if count < sparse.count { return }
        sparse.reserveCapacity(count)
        sparse += [Entity](repeating:-1, count: count - sparse.count)
    }

    public func set(_ ce : ComponentEntry<T> ){
        let denseIndex = sparse[ce.entity]
        guard denseIndex != -1 else { add(ce); return }
        dense[denseIndex] = ce
    }

    public func get(_ entity :Entity ) -> T? {
        let denseIndex = sparse[entity]
        guard denseIndex != -1 else { return nil }
        return dense[denseIndex].component
    }


    public func getAsKeyValues() -> LazySequence<[(entity: Entity, component: T)]> {
        return dense.lazy
    }
}


// even slower, that's worth something I guess 

// class ComponentSet<T: Component>: ComponentStorage {
//     private var storage: [Entity: T] = [:]

//     public init() {
//         storage.reserveCapacity(512)
//     }

//     public func add(_ ce: ComponentEntry<T>) {
//         storage[ce.entity] = ce.component
//     }

//     public func setEntityCount(_ count: Int) {
//         // Not needed when using a dictionary
//     }

//     public func set(_ ce: ComponentEntry<T>) {
//         storage[ce.entity] = ce.component
//     }

//     public func get(_ entity: Entity) -> T? {
//         return storage[entity]
//     }

//     public func getAsKeyValues() -> LazySequence<LazyMapSequence<LazySequence<[Entity : T]>.Elements, (entity: Entity, component: T)>.Elements> {
//         return storage.lazy.map({ (key, value) in return (entity:key, component:value) }).lazy
//     }
// }

// NOTE: maybe use ComponentMask max value to mark deleted components
class EntityComponentSystem {

    var entityHasComponent : [ComponentMask] = []
    var storages: [ComponentStorage] = []

    public var entityCount: Entity = 0

    public init(){}

    public func CreateEntities(_ n: Int = 1){
        if n < 1 { return }
        entityCount += n
        if n == 1 { entityHasComponent.append(0); return }
        entityHasComponent += [ComponentMask](repeating: 0, count: n)
        for s in storages { s.setEntityCount(entityCount) }
    }

    func getStorage<T : Component>() -> ComponentSet<T> {
        return storages[T.self.componentId] as! ComponentSet<T>
    }

    public func addComponentType<T : Component>(_ type: T.Type) {
        if type.componentId == -1 {
            type.componentId = storages.count
            let storage = ComponentSet<T>()
            storage.setEntityCount(entityCount)
            storages.append(storage)
        }
    }
    
    public func addComponent<T : Component>(_ component : T, entity : Entity) {
        let componentId = T.self.componentId
        entityHasComponent[entity] |= 1 << componentId
        let storage = storages[componentId] as! ComponentSet<T>
        storage.add((entity, component))
        storages[componentId] = storage
    }

    public func componentMask<T : Component>(_ type : T.Type) -> ComponentMask {
        return 1 << type.componentId
    }

    public func hasComponents(_ entity : Entity, _ mask : ComponentMask ) -> Bool{
        return entityHasComponent[entity] & mask != 0
    }

    public func ForEach<T : Component>(_ typeT : T.Type) -> ComponentSet<T> {
        let t :ComponentSet<T> = getStorage()
        return t
    }

    public func ForEach<T : Component, U : Component>(_ typeT : T.Type, _ typeU : U.Type)
    -> LazyMapSequence<LazySequence<Zip2Sequence<LazyFilterSequence<LazySequence<[(entity: Entity, component: T)]>.Elements>, LazyFilterSequence<LazySequence<[(entity: Entity, component: U)]>.Elements>>>.Elements, (Entity, T, U)>
    {
        let t :ComponentSet<T> = getStorage()
        let u :ComponentSet<U> = getStorage()
        let mask = componentMask(T.self) | componentMask(U.self)
        return zip(
            t.getAsKeyValues().filter { return self.hasComponents($0.entity, mask) },
            u.getAsKeyValues().filter { return self.hasComponents($0.entity, mask) }
        ).lazy.map({ return ($0.entity, $0.component, $1.component) })
    }

}