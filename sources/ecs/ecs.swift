
// TODO:
// change foreach to use Componentsets as argument (not ecs itself)
// add more foreach declinations

struct EntityProxy{
    var scene : ECScene
    var entity : Entity

    func add<T : Component>(_ component:T){
        scene.add(entity, component)
    }

    //  TODO: could be useful
    // public func addComponents(_ mask : ComponentMask)

    func hasComponents(_ mask : ComponentMask ) -> Bool {
        return scene.hasComponents(entity, mask)
    }

    func delete(){
        scene.deleteEntity(entity)
    }
}

class ECScene {
    var typeIdToComponentId = [TypeId : ComponentId]()
    var storages = [ComponentStorage]()

    var maxEntities : Entity = 0
    var entityHasComponent = [ComponentMask]()
    var deletedEntities = Set<Entity>()

    public init(){
        deletedEntities.reserveCapacity(512)
    }

    // returns deleted entities if possible
    // TODO: return a custom iterator
    public func createEntities(_ n: Int = 1) -> [Entity] {
        guard n > 0 else { return [] }
        var n = n
        var res = [Entity]()
        if !deletedEntities.isEmpty {
            let removed = min(n, deletedEntities.count)
            for _ in 0..<removed {
                res.append( deletedEntities.first! )
                deletedEntities.removeFirst()
            }
            n -= removed
            if n == 0 { return res }
        }
        defer {
            maxEntities += n
            for s in storages { s.setEntityCount(maxEntities) }
        }
        entityHasComponent += [ComponentMask](repeating: 0, count: n)
        return res + (maxEntities..<maxEntities+n)
    }

    public func Component<T : Component>(_ type: T.Type) {
        let typeId = TypeId(type)
        let componentId = typeIdToComponentId[typeId]
        guard componentId == nil else { return }
        typeIdToComponentId[typeId] = typeIdToComponentId.count
        type.typeId = typeId
        let storage = ComponentSet<T>() as ComponentStorage
        addStorage(typeId, storage)
    }

    private func addStorage(_ typeId:TypeId, _ storage:ComponentStorage){
        storage.setComponentMask(1 << storages.count)
        storage.setEntityCount(maxEntities)
        storages.append(storage)
    }

    subscript(_ entity : Entity) -> EntityProxy {
        get {
            return EntityProxy(scene:self, entity:entity)
        }
    }

    public func add<T : Component>(_ entity : Entity, _ component : T) {
        let typeId = T.self.typeId
        let componentId = typeIdToComponentId[typeId]!
        let storage = storages[componentId] as! ComponentSet<T>
        entityHasComponent[entity] |= storage.componentMask
        storage.add(entity, component)
        storages[componentId] = storage // keep this !
    }

    public func hasComponents(_ entity : Entity, _ mask : ComponentMask ) -> Bool{
        return entityHasComponent[entity] & mask != 0
    }

    func deleteEntity(_ entity:Entity){
        guard entity < maxEntities && !deletedEntities.contains(entity) else { return }
        deletedEntities.insert(entity)
        defer { entityHasComponent[entity] = 0 }
        for (i,s) in storages.enumerated() where hasComponents(entity, 1<<i) {
            s.remove(entity);
        }
    }

    public func list<T : Component>(_ type : T.Type) -> ComponentSet<T> {
        let componentId = typeIdToComponentId[T.self.typeId]!
        return storages[componentId] as! ComponentSet<T>
    }

    public func forEach<T : Component, U : Component>(_ typeT : T.Type, _ typeU : U.Type)
    -> LazyMapSequence<LazyFilterSequence<[ComponentEntry<T>]>, (Entity, T, U)>
    {
     let t = list(typeT)
     let u = list(typeU)
     let mask = t.componentMask | u.componentMask
     return t.iterate()
         .filter{ self.hasComponents($0.entity, mask) }
         .map({ ($0.entity, $0.component, u[$0.entity]) })
    }

    // should be faster than setting through ComponentSet
    // not seeing though
    // maybe better when the sets are actually sparse
    public func forEachModifiable<T : Component, U : Component>(_ typeT : T.Type, _ typeU : U.Type)
    -> LazyMapSequence<LazyFilterSequence<LazySequence<ComponentProxySequence<T>>.Elements>, (LazyFilterSequence<LazySequence<ComponentProxySequence<T>>.Elements>.Element, ComponentProxy<U>)>
    {
     let t = list(typeT)
     let u = list(typeU)
     let mask = t.componentMask | u.componentMask
     return t.iterateModify()
         .filter{ self.hasComponents($0.entity, mask) }
         .map({ ($0, u.getProxy($0.entity)) })
    }

}
