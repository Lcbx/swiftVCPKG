


protocol ComponentStorage {

    var componentMask : ComponentMask {get set}

    var entryCount : Int { get } 

    func setEntityCount(_ count :Int)
    func setComponentMask(_ mask :ComponentMask)

    func remove(_ from:Entity)
}

typealias ComponentEntry<T:Component> = (entity:Entity, component:T)

// TODO : split into single component entity set and multi-component entity set

typealias DenseIndex = Int
class ComponentSet<T : Component> : ComponentStorage {

    public var componentMask : ComponentMask = ComponentMask.max

    // sparse maps Entities to indices into dense
    var sparse = [DenseIndex]()
    //var storage : StorageSetWrapper<T>
    var storage : SimpleSet<T>
    var deletedCount : Int = 0

    public init(double_buffered:Bool=false, capacity : Int = 512){
        storage = SimpleSet<T>(capacity:capacity)
        //if double_buffered {
        //    storage = StorageSetWrapper(DoubleBufferedSet<T>(capacity:capacity))
        //}
        //else {
        //    storage = StorageSetWrapper(SimpleSet<T>(capacity:capacity))
        //}
    }

    public var internalCount : Int {
        get { return storage.count }
    }

    public var entryCount : Int {
        get { return storage.count - deletedCount }
    }


    public func setComponentMask(_ mask :ComponentMask){
        self.componentMask = mask
    }

    public func setEntityCount(_ count :Int){
        if count < sparse.count { return }
        sparse.reserveCapacity(count)
        sparse += [DenseIndex](repeating:0, count: count - sparse.count)
    }


    func remove(_ entity:Entity){
        let denseIndex = sparse[entity]
        guard storage.get_direct(denseIndex).entity == entity else { return }
        storage.remove_direct(denseIndex)
        deletedCount += 1
    }

    func remove_at(_ entity:Entity, index:Int){
        let denseIndex = sparse[entity] + index
        guard storage.get_direct(denseIndex).entity == entity else { return }
        storage.remove_direct(denseIndex)
        deletedCount += 1
    }

    public func upkeep() {
        //print("sparse ", sparse.count, " dense ", dense.count, " deleted ", deletedCount)
        guard storage.upkeep(deleted:deletedCount) else { return }
        deletedCount = 0
        for (i, (entity, _)) in storage.get_dense().enumerated() {
            sparse[entity] = i
        }
    }

    // can't be used to add component !
    public subscript(_ entity : Entity) -> T {
        get{ return get(entity).component }
        set{ set( (entity, newValue) ) }
    }

    public func add(_ ce : ComponentEntry<T>){
        let entity = ce.entity
        let denseIndex = sparse[entity]
        // already components for this entity ?
        // if it's the same entity as last added it's ok
        // otherwise move them all to the end
        if denseIndex != 0 && denseIndex < storage.count 
          && storage.get_direct(denseIndex).entity==entity {
            let newIndex = storage.add_direct( ce )
            if storage.get_direct(storage.count-1).entity != entity {
                for (i, c) in getAll(entity).enumerated(){
                    storage.add_direct( ce )
                    remove_at(entity, index:i)
                }
                sparse[entity] = newIndex
            }
        }
        else{
            let denseIndex = storage.add_direct(ce)
            sparse[entity] = denseIndex
        }
    }

    public func set(_ ce : ComponentEntry<T> ){
        let denseIndex = sparse[ce.entity]
        storage.set_direct(denseIndex, ce )
    }

    // used for modifying a component among many associated with same entity
    public func set_at(_ entity : Entity, index : Int, component: T){
        let denseIndex = sparse[entity] + index
        guard storage.get_direct(denseIndex).entity == entity else { return }
        storage.set_direct(denseIndex, (entity, component) )
    }

    public func get(_ entity : Entity ) -> ComponentEntry<T> {
        let denseIndex = sparse[entity]
        return storage.get_direct(denseIndex)
    }

    public func getAll(_ entity : Entity ) -> EntityComponentsSequence<T> {
        let denseIndex = sparse[entity]
        return EntityComponentsSequence(storage:storage,denseIndex:denseIndex,entity:entity)
    }

    public func iterate() -> ComponentSequence<T> {
        return ComponentSequence(sequence:iterateWithEntity())
    }

    public func iterateWithEntity() -> ComponentEntrySequence<T> {
        return ComponentEntrySequence(storage:storage)
    }

}

struct EntityComponentsSequence<T:Component> : Sequence, IteratorProtocol  {
    var storage : SimpleSet<T> // StorageSetWrapper<T>
    var denseIndex : DenseIndex 
    var entity : Entity
    public mutating func next() -> T? {
        var entry : ComponentEntry<T>
        repeat {
            denseIndex+=1
            guard denseIndex < storage.count else { return nil }
            entry = storage.get_direct(denseIndex)
        } while entry.entity == ENTITY_EMPTY
        if entry.entity != entity { return nil } 
        return entry.component
    }
}

struct ComponentEntrySequence<T:Component> : Sequence, IteratorProtocol  {
    var storage : SimpleSet<T> // StorageSetWrapper<T>
    var denseIndex : DenseIndex = -1

    public mutating func next() -> ComponentEntry<T>? {
        var entry : ComponentEntry<T>
        repeat {
            denseIndex+=1
            guard denseIndex < storage.count else { return nil }
            entry = storage.get_direct(denseIndex)
        } while entry.entity == ENTITY_EMPTY
        return entry
    }
}

struct ComponentSequence<T:Component> : Sequence, IteratorProtocol  {
    var sequence : ComponentEntrySequence<T>
    public mutating func next() -> T? {
        if let ce = sequence.next(){ return ce.component}
        return nil
    }
}

