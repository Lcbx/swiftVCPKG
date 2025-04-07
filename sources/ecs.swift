typealias Entity = Int
typealias TypeId = ObjectIdentifier
typealias ComponentId = Int
typealias ComponentMask = Int

typealias ComponentEntry<T> = (entity:Entity, component:T)

// TODO: make ComponentSet a SoA so we don't retrieve the entityId whenever we iterate it
typealias ComponentSet<T> = [ComponentEntry<T>]

// NOTE: maybe use ComponentMask max value to mark deleted components
class EntityComponentSystem {

    var componentTypeToStorage: [TypeId] = []
    var entityHasComponent : [ComponentMask] = []
    var storages: [Any] = []

    public var entityCount: Entity = 0

    public init(){}

    public func CreateEntities(_ n: Int = 1){
        entityCount += n
        if n == 1 { entityHasComponent.append(0); return }
        entityHasComponent += [ComponentMask](repeating: 0, count: n)
    }

    func getComponentId_impl(_ type:TypeId) -> ComponentId? { return componentTypeToStorage.firstIndex(of:type); }

    func getStorage<T>() -> ComponentSet<T> {
        let id = getComponentId_impl(TypeId(T.self))
        return storages[id!] as! ComponentSet<T>
    }

    public func getComponentId<T>(_ type: T.Type, capacity:Int=64) -> ComponentId {
        let typeId = TypeId(type)
        if let id = getComponentId_impl(typeId) { return id }
        componentTypeToStorage.append(typeId)
        var storage = ComponentSet<T>()
        storage.reserveCapacity(capacity)
        storages.append(storage)
        return componentTypeToStorage.count-1
    }
    
    public func addComponent<T>(_ component : T, entity : Entity) {
        let id = getComponentId_impl(TypeId(T.self))!
        addComponentFast(component, componentId:id, entity:entity)
    }

    public func addComponentFast<T>(_ component : T, componentId : ComponentId, entity : Entity) {
        var storage : ComponentSet<T> = storages[componentId] as! ComponentSet<T>
        entityHasComponent[entity] |= 1 << componentId
        storage.append((entity, component))
        storages[componentId] = storage
    }

    public func componentMask<T>(_ type : T.Type) -> ComponentMask {
        let id = getComponentId_impl(TypeId(T.self))!
        return 1 << id
    }

    public func componentMask(_ types : [TypeId] ) -> ComponentMask{
        var mask : ComponentMask = 0;
        for t in types{
            let id = getComponentId_impl(t)!
            mask |= 1 << id
        }
        return mask
    }

    public func hasComponents(_ entity : Entity, _ mask : ComponentMask ) -> Bool{
        return entityHasComponent[entity] & mask != 0
    }

    // need to keep storage sorted by entities if we want multi-component iterator to work 
    public func Sort<T>(_ type : T.Type) {
        var t :ComponentSet<T> = getStorage()
        t.sort(by: { return $0.entity > $1.entity })
    }

    public func ForEach<T>(_ typeT : T.Type) -> ComponentSet<T> {
        let t :ComponentSet<T> = getStorage()
        return t
    }

    public func ForEach<T, U>(_ typeT : T.Type, _ typeU : U.Type)
    -> LazyMapSequence<LazySequence<Zip2Sequence<ComponentSet<T>, [ComponentEntry<U>]>>.Elements, (Entity, T, U)> {
        let t :ComponentSet<T> = getStorage()
        let u :ComponentSet<U> = getStorage()
        let mask = componentMask( [TypeId(typeT), TypeId(typeU)] )
        return zip(
            t.filter { return self.hasComponents($0.entity, mask) },
            u.filter { return self.hasComponents($0.entity, mask) }
        ).lazy.map({ return ($0.entity, $0.component, $1.component) })
    }

}