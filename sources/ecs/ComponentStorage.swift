


typealias DenseIndex = Int
typealias ComponentEntry<T:Component> = (entity:Entity, component:T)


protocol ComponentStorage {
    var componentMask : ComponentMask {get set}
    var count : Int { get }
    var entryCount : Int { get } 
    var double_buffered : Bool { get }

    func setEntityCount(_ count :Int)
    func setComponentMask(_ mask :ComponentMask)
    func reserveCapacity(_ capacity : Int)
    func remove(_ entity:Entity)

    func remove_direct(_ denseIndex:DenseIndex)
    func add_direct(_ ce : Any) -> Int
    func set_direct(_ denseIndex : DenseIndex, _ entry : Any)
    func get_direct(_ denseIndex : DenseIndex ) -> Any
    func upkeep()
}

// TODO : split into single component entity set and multi-component entity set

class ComponentSet<Implementation : Any, T : Component> : ComponentStorage {

    public var componentMask : ComponentMask = ComponentMask.max

    // sparse maps Entities to indices into dense
    var sparse = [DenseIndex]()

    var deletedCount : Int = 0

    public var entryCount : Int {
        get { return count - deletedCount }
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
        guard get_direct_typed(denseIndex).entity == entity else { return }
        remove_direct(denseIndex)
        deletedCount += 1
    }

    func remove_at(_ entity:Entity, index:Int){
        let denseIndex = sparse[entity] + index
        guard get_direct_typed(denseIndex).entity == entity else { return }
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
        if denseIndex != 0 && denseIndex < count 
          && get_direct_typed(denseIndex).entity==entity {
            let newIndex = add_direct( ce )
            if get_direct_typed(count-1).entity != entity {
                for (i, c) in getAll(entity).enumerated(){
                    _ = add_direct( ce )
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
        guard get_direct_typed(denseIndex).entity == entity else { return }
        set_direct(denseIndex, (entity, component) )
    }

    public func get(_ entity : Entity ) -> ComponentEntry<T> {
        let denseIndex = sparse[entity]
        return get_direct_typed(denseIndex)
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

    @inline(__always)
    func get_direct_typed(_ denseIndex : DenseIndex ) -> ComponentEntry<T> {
        return get_direct(denseIndex) as! ComponentEntry<T>
    }

    // to be overriden
    var count : Int { get { -1 } }
    var double_buffered : Bool { get { false } }
    func reserveCapacity(_ capacity : Int) {}
    func remove_direct(_ denseIndex:DenseIndex) {}
    func add_direct(_ ce : Any) -> Int { -1 }
    func set_direct(_ denseIndex : DenseIndex, _ entry : Any) {}
    func get_direct(_ denseIndex : DenseIndex ) -> Any { -1 }
    func upkeep() {}

}

class DoubleBufferSet<T:Component> : ComponentSet<DoubleBufferSet, T> {

    // dense is for reads, dense2 is for writes
    var dense = [ComponentEntry<T>]()
    var dense2 = [ComponentEntry<T>]()

    public override var count : Int {
        get { return dense.count }
    }

    public override var double_buffered : Bool {
        get { true } 
    }

    public override func reserveCapacity(_ capacity : Int){
        dense.reserveCapacity(capacity)
        dense2.reserveCapacity(capacity)
    }

    public override func get_direct(_ denseIndex : DenseIndex ) -> Any {
        return dense[denseIndex]
    }

    public override func set_direct(_ denseIndex : DenseIndex, _ entry : Any){
        dense2[denseIndex] = entry as! ComponentEntry<T>
    }

    public override func remove_direct(_ denseIndex:DenseIndex){
        var ce = dense2[denseIndex]
        ce.entity = ENTITY_EMPTY
        dense2[denseIndex] = ce
    }

    public override func add_direct(_ ce : Any) -> Int {
        let denseIndex = dense.count
        dense2.append( ce as! ComponentEntry<T> )
        return denseIndex
    }

    // TODO: swapping buffers is needed each frame
    // but defragmentation should be scheduled as a sort of job
    // so it doesn't cause stutters when multiple components need to defragment at the same time
    // at the very least we should call upkeep a different thread for each ComponentSet 
    public override func upkeep() {
        // swap buffers
        //swap(&dense, &dense2)
        defer { dense = dense2 }

        guard deletedCount > 0 && dense.count / deletedCount < 3 else { return }
        //print(dense.count, deletedCount)
        // exploit that ENTITY_EMPTY is biggest number
        dense2.sort(by:{ $0.entity < $1.entity})
        dense2.removeLast(deletedCount)
        deletedCount = 0
        for (i, ce) in dense2.enumerated() {
            sparse[ce.entity] = i
        }
    }

}

class SingleBufferSet<T:Component> : ComponentSet<SingleBufferSet, T> {

    var dense = [ComponentEntry<T>]()

    public override var count : Int {
        get { return dense.count }
    }

    public override var double_buffered : Bool {
        get { false } 
    }

    public override func reserveCapacity(_ capacity : Int){
        dense.reserveCapacity(capacity)
    }

    public override func get_direct(_ denseIndex : DenseIndex ) -> Any {
        return dense[denseIndex]
    }

    public override func set_direct(_ denseIndex : DenseIndex, _ entry : Any){
       dense[denseIndex] = entry as! ComponentEntry<T>
    }

    public override func remove_direct(_ denseIndex:DenseIndex){
        var ce = dense[denseIndex]
        ce.entity = ENTITY_EMPTY
        dense[denseIndex] = ce
    }

    public override func add_direct(_ ce : Any) -> Int {
        let denseIndex = dense.count
        dense.append( ce as! ComponentEntry<T>)
        return denseIndex
    }


    public override func upkeep() {

        guard deletedCount > 0 && dense.count / deletedCount < 3 else { return }
        //print(dense.count, deletedCount)
        // exploit that ENTITY_EMPTY is biggest number
        dense.sort(by:{ $0.entity < $1.entity})
        dense.removeLast(deletedCount)
        deletedCount = 0
        for (i, ce) in dense.enumerated() {
            sparse[ce.entity] = i
        }
    }

}




struct EntityComponentsSequence<T:Component> : Sequence, IteratorProtocol  {
    var storage : ComponentStorage
    var denseIndex : DenseIndex 
    var entity : Entity
    public mutating func next() -> T? {
        var entry : ComponentEntry<T>
        repeat {
            denseIndex+=1
            guard denseIndex < storage.count else { return nil }
            entry = storage.get_direct(denseIndex) as! ComponentEntry<T>
        } while entry.entity == ENTITY_EMPTY
        if entry.entity != entity { return nil } 
        return entry.component
    }
}

struct ComponentEntrySequence<T:Component> : Sequence, IteratorProtocol  {
    var storage : ComponentStorage
    var denseIndex : DenseIndex = -1

    public mutating func next() -> ComponentEntry<T>? {
        var entry : ComponentEntry<T>
        repeat {
            denseIndex+=1
            guard denseIndex < storage.count else { return nil }
            entry = storage.get_direct(denseIndex) as! ComponentEntry<T>
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

