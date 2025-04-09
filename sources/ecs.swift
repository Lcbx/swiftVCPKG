


typealias Entity = Int

// TypeId is type always the same while ComponentId is specific to an ECScene
typealias ComponentId = Int
typealias TypeId = ObjectIdentifier

// Componentmask is one-hot encoded ComponentId
typealias ComponentMask = UInt

protocol Component {
    static var typeId : TypeId { get set }
}

typealias ComponentEntry<T : Component> = (entity:Entity, component:T)

protocol ComponentStorage {
    var sparse : [Entity] {get}
    
    //TODO: should be moved to ECScene I think
    var componentMask : ComponentMask {get}
    var componentTypeId : TypeId {get}

    func setEntityCount(_ count :Int)
    func setComponentMask(_ mask :ComponentMask)
}

class ComponentSet<T : Component> : ComponentStorage {
    
    //TODO: should be moved to ECScene I think 2
    public var componentMask : ComponentMask = UInt.max
    public var componentTypeId : TypeId

    public var sparse = [Entity]()
    public var dense = [ComponentEntry<T>]()


    public init(_ typeId:TypeId = TypeId(T.self), _ capacity : Int = 512){
        self.componentTypeId = typeId
        self.dense.reserveCapacity(capacity)
    }

    func setComponentMask(_ mask :ComponentMask){
        self.componentMask = mask
    }

    public func setEntityCount(_ count :Int){
        if count < sparse.count { return }
        sparse.reserveCapacity(count)
        sparse += [Entity](repeating:-1, count: count - sparse.count)
    }


    public func add(_ entity : Entity, _ component:T){
        add( (entity, component) )
    }

    public func add(_ ce : ComponentEntry<T>){
        sparse[ce.entity] = dense.count
        dense.append( ce )
    }

    public func set(_ entity : Entity, _ component:T){
        set( (entity, component) )
    }

    public func set(_ ce : ComponentEntry<T> ){
        let denseIndex = sparse[ce.entity]
        guard denseIndex != -1 else { add(ce); return }
        dense[denseIndex] = ce
    }

    public func get(_ entity : Entity ) -> T? {
        let denseIndex = sparse[entity]
        guard denseIndex != -1 else { return nil }
        return dense[denseIndex].component
    }

    public func KeyValues() -> LazySequence<[(entity: Entity, component: T)]> {
        return dense.lazy
    }

}

// TODO:
// use a dict<TypeId:ComponentId>
// move foreach to ComponentSet and use ComponentSets as arguments instead of types
// add operator[] overloads to get set components through storage
// add a scene operator[] overload that returns an entityProxy to avoid having to pass it all the time

// struct EntityProxy{
//     var entity : Entity
//     var scene : ECScene

//     func add<T : Component>(_ component:T){}
//     func hasComponents(_ mask : ComponentMask ){}
// }

class ECScene {
    var storages = [ComponentStorage]()

    var entityCount : Entity = 0
    var entityHasComponent = [ComponentMask]()

    public init(){
    }

    public func createEntities(_ n: Int = 1){
        if n == 1 { entityHasComponent.append(0); return }
        guard n > 0 else { return }
        entityCount += n
        entityHasComponent += [ComponentMask](repeating: 0, count: n)
        for s in storages { s.setEntityCount(entityCount) }
    }

    public func addComponentType<T : Component>(_ type: T.Type) {
        let typeId = TypeId(type)
        guard getComponentId(typeId) == nil else { return }
        type.typeId = typeId
        let storage = ComponentSet<T>(typeId) as ComponentStorage
        addStorage(storage)
    }

    private func addStorage( _ storage : ComponentStorage){
        storage.setComponentMask(1 << storages.count)
        storage.setEntityCount(entityCount)
        storages.append(storage)
    }

    private func getComponentId(_ typeId :TypeId) -> Int? {
        let id = storages.firstIndex(where: { $0.componentTypeId == typeId })
        return id
    }

    public func addComponent<T : Component>(_ component : T, entity : Entity) {
        if let componentId = getComponentId(TypeId(T.self)) {
            let storage = storages[componentId] as! ComponentSet<T>
            entityHasComponent[entity] |= storage.componentMask
            storage.add(entity, component)
            storages[componentId] = storage
        }
    }

    //public func addComponents(_ mask : ComponentMask, entity : Entity){}

    public func hasComponents(_ entity : Entity, _ mask : ComponentMask ) -> Bool{
        return entityHasComponent[entity] & mask != 0
    }

    public func list<T : Component>(_ type : T.Type) -> ComponentSet<T>? {
        guard let componentId = getComponentId(T.self.typeId) else { return nil }
        return (storages[componentId] as! ComponentSet<T>)
    }

    public func forEach<T : Component, U : Component>(_ typeT : T.Type, _ typeU : U.Type)
    -> LazyMapSequence<LazyFilterSequence<LazySequence<[(entity: Entity, component: T)]>.Elements>, (Entity, T, U)>
    {
        let t = list(typeT)!
        let u = list(typeU)!
        let mask = t.componentMask | u.componentMask
        return t.KeyValues()
            .filter { self.hasComponents($0.entity, mask) }
            .map({ ($0.entity, $0.component, u.get($0.entity)!) })
    }

}