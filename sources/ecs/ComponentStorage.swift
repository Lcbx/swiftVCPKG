


protocol ComponentStorage {

    var componentMask : ComponentMask {get set}

    var entryCount : Int { get } 

    func setEntityCount(_ count :Int)
    func setComponentMask(_ mask :ComponentMask)

    func remove(_ from:Entity)
}

typealias ComponentEntry<T : Component> = (entity:Entity, component:T)

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

    public subscript(_ cp : ComponentProxy<T>) -> T {
        get{ return cp.component }
        // can't be used to add component !
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
        let i = sparse[ce.entity]
        dense[i] = ce
    }

    public func get(_ entity : Entity ) -> T {
        let i = sparse[entity]
        return dense[i].component
    }

    public func getProxy(_ entity : Entity ) -> ComponentProxy<T> {
        let i = sparse[entity]
        return ComponentProxy(denseIndex:i, value:dense[i])
    }

    public func setProxy(_ cp : ComponentProxy<T>, _ value : T) {
        var ce = dense[cp.denseIndex]
        ce.component = value
        dense[cp.denseIndex] = ce
    }

    public func iterate() -> LazyFilterSequence<LazySequence<[ComponentEntry<T>]>.Elements> {
        return dense.lazy.filter{ $0.entity != EMPTY }
    }

    public func iterateModify() -> ComponentProxySequence<T> {
        return ComponentProxySequence(dense:dense)
    }

}

struct ComponentProxySequence<T:Component> : Sequence, IteratorProtocol  {
    var dense : [ComponentEntry<T>]
    var denseIndex : Int = -1

    public mutating func next() -> ComponentProxy<T>? {
        repeat {
            denseIndex+=1
            guard denseIndex < dense.count else { return nil }
        } while dense[denseIndex].entity == EMPTY
        return ComponentProxy(denseIndex:denseIndex, value: dense[denseIndex])
    }
}

struct ComponentProxy<T:Component> {
    var denseIndex : Int
    var value : ComponentEntry<T>

    public var entity : Entity {
        get{ return value.entity }
    }

    public var component : T {
        get{ return value.component }
    }
}