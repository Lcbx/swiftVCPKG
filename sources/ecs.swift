

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

typealias ComponentEntry<T : Component> = (entity:Entity, component:T)

protocol ComponentStorage {

    var componentMask : ComponentMask {get set}

    var entryCount : Int { get } 

    func setEntityCount(_ count :Int)
    func setComponentMask(_ mask :ComponentMask)

    func remove(_ from:Entity)
}

// NOTE: I intend to support multiple components of same type per entity
// by simply putting them next to each other in the same container
// but that makes some of the handling trickier
// what about wanting to delete only some of the components associated with an entity ?
class ComponentSet<T : Component> : ComponentStorage {

    public var componentMask : ComponentMask = ComponentMask.max

    var sparse = [Entity]()
    var dense = [ComponentEntry<T>]()

    var deletedCount : Int = 0

    public var entryCount : Int {
        get { return dense.count - deletedCount }
    }


    public init(_ capacity : Int = 512){
        self.dense.reserveCapacity(capacity)
    }

    public func setComponentMask(_ mask :ComponentMask){
        self.componentMask = mask
    }

    public func setEntityCount(_ count :Int){
        if count < sparse.count { return }
        sparse.reserveCapacity(count)
        // setting to 0 instead of EMPTY since it should not be relied on anyway
        sparse += [Entity](repeating:0, count: count - sparse.count)
    }

    // TODO: ignore deleted when iterating
    func remove(_ entity:Entity){
        let i = sparse[entity]
        let ce = dense[i]
        dense[i] = (EMPTY, ce.component)
        deletedCount += 1
        
        if dense.count / deletedCount < 3 {

            // exploit that EMPTY is biggest number
            dense.sort(by:{ $0.entity < $1.entity})
            dense.removeLast(deletedCount)

            deletedCount = 0
            for (i, (entity, _)) in dense.enumerated() {
                sparse[entity] = i
            }
        }
    }

    public subscript(_ entity : Entity) -> T? {
        get{ return get(entity) }
        // can't be used to add component !
        set{ set(entity, newValue!) }
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
        let i = sparse[ce.entity]
        dense[i] = ce
    }

    public func get(_ entity : Entity ) -> T? {
        let i = sparse[entity]
        return dense[i].component
    }

    public func KeyValues() -> LazySequence<[(entity: Entity, component: T)]> {
        return dense.lazy
    }

}

// TODO:
// move foreach to ComponentSet and use ComponentSets as arguments instead of types

struct EntityProxy{
    var scene : ECScene
    var entity : Entity

    func add<T : Component>(_ component:T){
        scene.add(entity, component)
    }

    // could be useful
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

    var entityCount : Entity = 0
    var entityHasComponent = [ComponentMask]()
    var deletedEntities = [Entity]()

    public init(){
        deletedEntities.reserveCapacity(512)
    }

    // TODO: return an iterator which contains the genrated ids
    // since we recycle them
    public func createEntities(_ n: Int = 1) {
        guard n > 0 else { return }
        var n = n
        if !deletedEntities.isEmpty {
            let removed = min(n,deletedEntities.count)
            deletedEntities.removeLast(removed)
            n -= removed
        }
        if n == 1 { entityHasComponent.append(0); return }
        guard n > 0 else { return }
        entityCount += n
        entityHasComponent += [ComponentMask](repeating: 0, count: n)
        for s in storages { s.setEntityCount(entityCount) }
    }

    public func addType<T : Component>(_ type: T.Type) {
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
        storage.setEntityCount(entityCount)
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
        deletedEntities.append(entity)
        for (i,s) in storages.enumerated()
            where hasComponents(entity, 1<<i) {
            s.remove(entity);
        }
    }

    public func list<T : Component>(_ type : T.Type) -> ComponentSet<T> {
        let componentId = typeIdToComponentId[T.self.typeId]!
        return storages[componentId] as! ComponentSet<T>
    }

    public func forEach<T : Component, U : Component>(_ typeT : T.Type, _ typeU : U.Type)
    -> LazyMapSequence<LazyFilterSequence<LazySequence<[(entity: Entity, component: T)]>.Elements>, (Entity, T, U)>
    {
        let t = list(typeT)
        let u = list(typeU)
        let mask = t.componentMask | u.componentMask
        return t.KeyValues()
            .filter { $0.entity != EMPTY && self.hasComponents($0.entity, mask) }
            .map({ ($0.entity, $0.component, u.get($0.entity)!) })
    }


}
