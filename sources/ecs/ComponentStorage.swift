


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
    var dense = [ComponentEntry<T>]()
    var deletedCount : Int = 0

    public init(_ capacity : Int = 512){
        self.dense.reserveCapacity(capacity)
    }

    public var internalCount : Int {
        get { return dense.count }
    }

    public var entryCount : Int {
        get { return dense.count - deletedCount }
    }

    var defragment_needed : Bool {
        get { return dense.count / deletedCount < 3 }
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
        guard dense[denseIndex].entity == entity else { return }
        remove_direct(denseIndex)
    }

    func remove_at(_ entity:Entity, index:Int){
        let denseIndex = sparse[entity] + index
        guard dense[denseIndex].entity == entity else { return }
        remove_direct(denseIndex)
    }

    func remove_direct(_ denseIndex:DenseIndex){
        dense[denseIndex].entity = ENTITY_EMPTY
        deletedCount += 1
    }

    public func upkeep() {
        //print("sparse ", sparse.count, " dense ", dense.count, " deleted ", deletedCount)
        guard defragment_needed else { return }
        // exploit that ENTITY_EMPTY is biggest number
        dense.sort(by:{ $0.entity < $1.entity})
        dense.removeLast(deletedCount)

        deletedCount = 0
        for (i, (entity, _)) in dense.enumerated() {
            sparse[entity] = i
        }
    }


    // can't be used to add component !
    public subscript(_ entity : Entity) -> T {
        get{ return get_component(entity) }
        set{ set(entity, newValue) }
    }


    public func add(_ entity : Entity, _ component:T){
        add( (entity, component) )
    }

    // already components for this entity ?
    // if it's the last added we can just add it
    // otherwise move them to the end
    public func add(_ ce : ComponentEntry<T>){
        let entity = ce.entity
        if dense.count>0 && dense.last!.entity != entity && get(entity).entity == entity {
            for (i, c) in getAll(entity).enumerated(){
                add_direct( (entity, c) )
                remove_at(entity, index:i)
            }
        }
        add_direct(ce)
    }

    public func add_direct(_ ce : ComponentEntry<T>){
        sparse[ce.entity] = dense.count
        dense.append( ce )
    }

    public func set(_ entity : Entity, _ component:T){
        set( (entity, component) )
    }

    public func set(_ ce : ComponentEntry<T> ){
        let denseIndex = sparse[ce.entity]
        dense[denseIndex] = ce
    }

    // used for modifying a component among many associated with same entity
    public func set_at(_ entity : Entity, index : Int, component: T){
        let denseIndex = sparse[entity] + index
        guard get_direct(denseIndex).entity == entity else { return }
        set_direct(denseIndex, component)
    }

    public func set_direct(_ denseIndex : DenseIndex, _ component : T){
        dense[denseIndex].component = component
    }

    public func get_component(_ entity : Entity ) -> T {
        return get(entity).component
    }

    public func get(_ entity : Entity ) -> ComponentEntry<T> {
        let denseIndex = sparse[entity]
        return get_direct(denseIndex)
    }

    public func getAll(_ entity : Entity ) -> EntityComponentsSequence<T> {
        let denseIndex = sparse[entity]
        return EntityComponentsSequence(storage:self,denseIndex:denseIndex,entity:entity)
    }

    public func get_direct(_ denseIndex : DenseIndex ) -> ComponentEntry<T> {
        return dense[denseIndex]
    }

    public func iterate() -> ComponentSequence<T> {
        return ComponentSequence(sequence:iterateWithEntity())
    }

    public func iterateWithEntity() -> ComponentEntrySequence<T> {
        return ComponentEntrySequence(storage:self)
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

