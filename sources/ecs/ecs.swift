
// TODO : add tests

class ECScene {
    var typeIdToComponentId = [TypeId : ComponentId]()
    var storages = [ComponentStorage]()

    var maxEntities : Entity = 0
    var entityHasComponent = [ComponentMask]()
    var deletedEntities = [Entity]()

    public init(){
        deletedEntities.reserveCapacity(512)
    }

    var entityCount : Int { return maxEntities - deletedEntities.count }

    // returns deleted entities if possible
    public func createEntities(_ n: Int = 1) -> [Entity] {
        guard n > 0 else { return [] }
        var n = n
        var res = [Entity]()
        if !deletedEntities.isEmpty {
            let removed = min(n, deletedEntities.count)
            res += deletedEntities.suffix(n)
            deletedEntities.removeLast(n)
            n -= removed
            if n == 0 { return res }
        }
        entityHasComponent += [ComponentMask](repeating: COMPONENT_DELETED, count: n)
        res += (maxEntities..<maxEntities+n).lazy
        maxEntities += n
        for s in storages { s.setEntityCount(maxEntities) }
        return res
    }

    public func Component<T : Component>(_ type: T.Type) {
        let typeId = TypeId(type)
        let componentId = typeIdToComponentId[typeId]
        guard componentId == nil else { return }
        typeIdToComponentId[typeId] = ComponentId(storages.count)
        type.typeId = typeId
        var storage = ComponentSet<T>() as ComponentStorage
        addStorage(typeId, &storage)
    }

    private func addStorage(_ typeId:TypeId, _ storage: inout ComponentStorage){
        storage.componentMask = 1 << storages.count
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
        let storage = storages[Int(componentId)] as! ComponentSet<T>
        entityHasComponent[entity] |= storage.componentMask
        storage.add( (entity, component) )
		//print(entity, entityHasComponent[entity])
    }

    public func hasComponents(_ entity : Entity, _ mask : ComponentMask ) -> Bool{
        return (entityHasComponent[entity] & mask) == mask
    }

    func deleteEntity(_ entity:Entity){
        guard entity < maxEntities && entityHasComponent[entity] != COMPONENT_DELETED else { return }
        defer { entityHasComponent[entity] = COMPONENT_DELETED }
        deletedEntities.append(entity)
        for (i,s) in storages.enumerated() where hasComponents(entity, 1<<i) {
            s.remove(entity);
        }
    }

    public func list<T : Component>(_ type : T.Type) -> ComponentSet<T> {
        let componentId = typeIdToComponentId[T.self.typeId]!
        return storages[Int(componentId)] as! ComponentSet<T>
    }

}

struct EntityProxy{
    var scene : ECScene
    var entity : Entity

    func add<T : Component>(_ component:T){
        scene.add(entity, component)
    }

    //  TODO:
    //public func addComponents(_ mask : ComponentMask)

    func hasComponents(_ mask : ComponentMask ) -> Bool {
        return scene.hasComponents(entity, mask)
    }

    func delete(){
        scene.deleteEntity(entity)
    }
}



// TODO: generate nth Component versions in another file
extension ECScene {

    func iterateWithEntity<T : Component, U : Component>(
        _ t : ComponentSet<T>,
        _ u : ComponentSet<U>)
    -> [(Entity, T, U)]
    {
     let mask = t.componentMask | u.componentMask
     return t.iterateWithEntity()
         .filter { self.hasComponents($0.entity, mask) }
         .map { ($0.entity, $0.component, u[$0.entity]) }
    }

    func iterate<T : Component, U : Component>(
        _ t : ComponentSet<T>,
        _ u : ComponentSet<U>)
    -> [(T, U)]
    {
     let mask = t.componentMask | u.componentMask
     return t.iterateWithEntity()
         .filter { self.hasComponents($0.entity, mask) }
         .map { ($0.component, u[$0.entity]) }
    }

}