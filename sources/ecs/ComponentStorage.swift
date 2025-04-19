


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

    // when double-buffered, dense is for reads, dense2 is for writes
    var dense = [ComponentEntry<T>]()
    var dense2 : [ComponentEntry<T>]?

    var deletedCount : Int = 0

    public var double_buffered : Bool {
        get { return dense2 != nil } 
    }

    public init(double_buffered:Bool=false, capacity : Int = 512){
        dense.reserveCapacity(capacity)
        if double_buffered {
            dense2 = [ComponentEntry<T>]()
            dense2!.reserveCapacity(capacity)
        }
    }

    public var internalCount : Int {
        get { return dense.count }
    }

    public var entryCount : Int {
        get { return dense.count - deletedCount }
    }


    public func setComponentMask(_ mask :ComponentMask){
        self.componentMask = mask
    }

    public func setEntityCount(_ count :Int){
        if count < sparse.count { return }
        sparse.reserveCapacity(count)
        sparse += [DenseIndex](repeating:ENTITY_EMPTY, count: count - sparse.count)
    }


    func remove(_ entity:Entity){
        let denseIndex = sparse[entity]
        guard get_direct(denseIndex).entity == entity else { return }
        remove_direct(denseIndex)
        deletedCount += 1
    }

    func remove_at(_ entity:Entity, index:Int){
        let denseIndex = sparse[entity] + index
        guard get_direct(denseIndex).entity == entity else { return }
        remove_direct(denseIndex)
        deletedCount += 1
    }


    // NOTE: can't be used to add component
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
        if denseIndex != 0 && denseIndex < internalCount 
          && get_direct(denseIndex).entity==entity {
            let newIndex = add_direct( ce )
            if get_direct(internalCount-1).entity != entity {
                for (i, c) in getAll(entity).enumerated(){
                    add_direct( ce )
                    remove_at(entity, index:i)
                }
                sparse[entity] = newIndex
            }
        }
        else{
            let denseIndex = add_direct(ce)
            sparse[entity] = denseIndex
        }
    }

    public func set(_ ce : ComponentEntry<T> ){
        let denseIndex = sparse[ce.entity]
        set_direct(denseIndex, ce )
    }

    // used for modifying a component among many associated with same entity
    public func set_at(_ entity : Entity, index : Int, component: T){
        let denseIndex = sparse[entity] + index
        guard get_direct(denseIndex).entity == entity else { return }
        set_direct(denseIndex, (entity, component) )
    }

    public func get(_ entity : Entity ) -> ComponentEntry<T> {
        let denseIndex = sparse[entity]
        return get_direct(denseIndex)
    }

    public func getAll(_ entity : Entity ) -> EntityComponentsSequence<T> {
        let denseIndex = sparse[entity]
        return EntityComponentsSequence(storage:self,denseIndex:denseIndex,entity:entity)
    }

    public func iterate() -> ComponentSequence<T> {
        return ComponentSequence(sequence:iterateWithEntity())
    }

    public func iterateWithEntity() -> ComponentEntrySequence<T> {
        return ComponentEntrySequence(storage:self)
    }

    // TODO: swapping buffers is needed each frame
    // but defragmentation should be scheduled as a sort of job
    // so it doesn't cause stutters when multiple components need to defragment at the same time
    // at the very least we should call upkeep a different thread for each ComponentSet 
    public func upkeep() {
        // swap buffers
        //swap(&dense, &dense2!)
        defer { if double_buffered { dense = dense2! } }

        guard deletedCount > 0 && dense.count / deletedCount < 3 else { return }
        //print(dense.count, deletedCount)
        // exploit that ENTITY_EMPTY is biggest number
        if double_buffered {
            dense2!.sort(by:{ $0.entity < $1.entity})
            dense2!.removeLast(deletedCount)
            deletedCount = 0
            for (i, ce) in dense2!.enumerated() {
                sparse[ce.entity] = i
            }
        }
        else{
            dense.sort(by:{ $0.entity < $1.entity})
            dense.removeLast(deletedCount)
            deletedCount = 0
            for (i, ce) in dense.enumerated() {
                sparse[ce.entity] = i
            }
        }
    }

    @inline(__always)
    public func get_direct(_ denseIndex : DenseIndex ) -> ComponentEntry<T> {
        return dense[denseIndex]
    }

    @inline(__always)
    public func set_direct(_ denseIndex : DenseIndex, _ entry : ComponentEntry<T>){
        if double_buffered
             { dense2![denseIndex] = entry }
        else { dense[denseIndex] = entry }
    }

    @inline(__always)
    public func remove_direct(_ denseIndex:DenseIndex){
        if double_buffered{
            var ce = dense2![denseIndex]
            ce.entity = ENTITY_EMPTY
            dense2![denseIndex] = ce
        }
        else{
            var ce = dense[denseIndex]
            ce.entity = ENTITY_EMPTY
            dense[denseIndex] = ce
        }
    }

    @inline(__always)
    public func add_direct(_ ce : ComponentEntry<T>) -> Int {
        let denseIndex = dense.count
        dense.append( ce )
        if double_buffered { dense2!.append( ce ) }
        return denseIndex
    }


}

struct EntityComponentsSequence<T:Component> : Sequence, IteratorProtocol  {
    var storage : ComponentSet<T>
    var denseIndex : DenseIndex 
    var entity : Entity
    public mutating func next() -> T? {
        var entry : ComponentEntry<T>
        repeat {
            denseIndex+=1
            guard denseIndex < storage.internalCount else { return nil }
            entry = storage.get_direct(denseIndex)
        } while entry.entity == ENTITY_EMPTY
        if entry.entity != entity { return nil } 
        return entry.component
    }
}

struct ComponentEntrySequence<T:Component> : Sequence, IteratorProtocol  {
    var storage : ComponentSet<T>
    var denseIndex : DenseIndex = -1

    public mutating func next() -> ComponentEntry<T>? {
        var entry : ComponentEntry<T>
        repeat {
            denseIndex+=1
            guard denseIndex < storage.internalCount else { return nil }
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

