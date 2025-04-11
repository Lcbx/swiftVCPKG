


protocol ComponentStorage {

    var componentMask : ComponentMask {get set}

    var entryCount : Int { get } 

    func setEntityCount(_ count :Int)
    func setComponentMask(_ mask :ComponentMask)

    func remove(_ from:Entity)
}

typealias ComponentEntry<T:Component> = (entity:Entity, component:T)

// NOTE: I intend to support multiple components of same type per entity
// by simply putting them next to each other in the same container
// TODO: add getAll(entity) -> [Component]
// TODO: add delete(criteria : (Component) -> Bool)
// TODO: when adding component, if already has some,
//      move existing ones to end and add add last

class ComponentSet<T : Component> : ComponentStorage {

    public var componentMask : ComponentMask = ComponentMask.max

    var sparse = [Entity]()
    public var dense = [ComponentEntry<T>]()

    var deletedCount : Int = 0

    public var internalCount : Int {
        get { return dense.count }
    }

    public var entryCount : Int {
        get { return dense.count - deletedCount }
    }

    var defragment_needed : Bool {
        get { return dense.count / deletedCount < 3 }
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

    func remove(_ entity:Entity){
        let i = sparse[entity]
        let ce = dense[i]
        dense[i] = (EMPTY, ce.component)
        deletedCount += 1
    }

    public func upkeep() {
        //print("sparse ", sparse.count, " dense ", dense.count, " deleted ", deletedCount)
        guard defragment_needed else { return }
        // exploit that EMPTY is biggest number
        dense.sort(by:{ $0.entity < $1.entity})
        dense.removeLast(deletedCount)

        deletedCount = 0
        for (i, (entity, _)) in dense.enumerated() {
            sparse[entity] = i
        }
    }

    // can't be used to add component !
    public subscript(_ entity : Entity) -> T {
        get{ return get(entity) }
        set{ set(entity, newValue) }
    }

    public subscript(_ entity : Entity) -> ComponentEntry<T> {
        get{ return get(entity) }
        set{ set(newValue) }
    }

    public subscript(_ cp : ComponentProxy<T>) -> T {
       get{ return cp.component }
       set{ setProxy(cp, newValue) }
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
        dense[denseIndex] = ce
    }

    public func get(_ entity : Entity ) -> T {
        return get(entity).component
    }

    public func get(_ entity : Entity ) -> ComponentEntry<T> {
        let denseIndex = sparse[entity]
        return get_direct(denseIndex)
    }

    public func get_direct(_ denseIndex : Int ) -> ComponentEntry<T> {
        return dense[denseIndex]
    }

    public func getProxy(_ entity : Entity ) -> ComponentProxy<T> {
        let denseIndex = sparse[entity]
        let entry = dense[denseIndex]
        return ComponentProxy(entity:entry.entity, component:entry.component, denseIndex:denseIndex)
    }

    public func setProxy(_ cp : ComponentProxy<T>, _ component : T) {
        var ce = dense[cp.denseIndex]
        ce.component = component
        dense[cp.denseIndex] = ce
    }

    public func iterate() -> LazyFilterSequence<LazySequence<[ComponentEntry<T>]>.Elements> {
        return dense.lazy.filter{ $0.entity != EMPTY }
    }

    public func iterateModify() -> LazySequence<ComponentProxySequence<T>> {
        return ComponentProxySequence(storage:self).lazy
    }

}

struct ComponentProxySequence<T:Component> : Sequence, IteratorProtocol  {
    var storage : ComponentSet<T>
    var denseIndex : Int = -1

    public mutating func next() -> ComponentProxy<T>? {
        var entry : ComponentEntry<T>
        repeat {
            denseIndex+=1
            guard denseIndex < storage.internalCount else { return nil }
            entry = storage.get_direct(denseIndex)
        } while entry.entity == EMPTY
        return ComponentProxy(entity:entry.entity, component:entry.component, denseIndex:denseIndex)
    }
}

struct ComponentProxy<T:Component> {
    var entity : Entity
    var component : T
    var denseIndex : Int
}