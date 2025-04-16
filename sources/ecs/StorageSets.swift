

//typealias DenseIndex = Int
//typealias ComponentEntry<T:Component> = (entity:Entity, component:T)

protocol StorageSet {
    associatedtype C : Component

    var count : Int { get }
    var double_buffered : Bool { get }
    func get_dense() -> [ComponentEntry<C>]
    func upkeep(deleted:Int) -> Bool

    func get_direct(_ denseIndex : DenseIndex ) -> ComponentEntry<C>
    func set_direct(_ denseIndex : DenseIndex, _ entry : ComponentEntry<C>)
    func remove_direct(_ denseIndex:DenseIndex)
    func add_direct(_ ce : ComponentEntry<C>) -> Int
}

// wrapper since swift is dumb
struct StorageSetWrapper<C: Component>: StorageSet {
    private let _count: () -> Int
    private let _double_buffered: () -> Bool
    private let _get_dense: () -> [ComponentEntry<C>]
    private let _upkeep: (Int) -> Bool

    private let _get_direct: (DenseIndex) -> ComponentEntry<C>
    private let _set_direct: (DenseIndex, ComponentEntry<C>) -> Void
    private let _remove_direct: (DenseIndex) -> Void
    private let _add_direct: (ComponentEntry<C>) -> Int

    init<S: StorageSet>(_ storage: S) where S.C == C {
        _count = { storage.count }
        _double_buffered = { storage.double_buffered }
        _get_dense = { storage.get_dense() }
        _upkeep = { storage.upkeep(deleted: $0) }

        _get_direct = { storage.get_direct($0) }
        _set_direct = { storage.set_direct($0, $1) }
        _remove_direct = { storage.remove_direct($0) }
        _add_direct = { storage.add_direct($0) }
    }

    @inline(__always)
    var count: Int { _count() }
    @inline(__always)
    var double_buffered: Bool { _double_buffered() }
    @inline(__always)
    func get_dense() -> [ComponentEntry<C>] { _get_dense() }
    @inline(__always)
    func upkeep(deleted: Int) -> Bool { _upkeep(deleted) }
    @inline(__always)
    func get_direct(_ denseIndex: DenseIndex) -> ComponentEntry<C> {
        _get_direct(denseIndex)
    }
    @inline(__always)
    func set_direct(_ denseIndex: DenseIndex, _ entry: ComponentEntry<C>) {
        _set_direct(denseIndex, entry)
    }
    @inline(__always)
    func remove_direct(_ denseIndex: DenseIndex) {
        _remove_direct(denseIndex)
    }
    @inline(__always)
    func add_direct(_ ce: ComponentEntry<C>) -> Int {
        _add_direct(ce)
    }
}



class SimpleSet<T : Component> : StorageSet {
    typealias C = T

    public var dense = [ComponentEntry<T>]()
    public var double_buffered : Bool { return false }

    public init(capacity : Int = 512){
        self.dense.reserveCapacity(capacity)
    }

    @inline(__always)
    public var count : Int { get { return dense.count} }

    @inline(__always)
    public func get_dense() -> [ComponentEntry<T>] {
        return dense
    }

    @inline(__always)
    public func get_direct(_ denseIndex : DenseIndex ) -> ComponentEntry<T> {
        return dense[denseIndex]
    }

    @inline(__always)
    public func set_direct(_ denseIndex : DenseIndex, _ entry : ComponentEntry<T>){
        dense[denseIndex] = entry
    }

    @inline(__always)
    public func remove_direct(_ denseIndex:DenseIndex){
        dense[denseIndex].entity = ENTITY_EMPTY
    }

    @inline(__always)
    public func add_direct(_ ce : ComponentEntry<T>) -> Int {
        let denseIndex = dense.count
        dense.append( ce )
        return denseIndex
    }

    @inline(__always)
    public func upkeep(deleted:Int) -> Bool {
        guard deleted > 0 && dense.count / deleted < 3 else { return false }

        // exploit that ENTITY_EMPTY is biggest number
        dense.sort(by:{ $0.entity < $1.entity})
        dense.removeLast(deleted)
        return true
    }

}

class DoubleBufferedSet<T : Component> : StorageSet {
    typealias C = T

    // standard : dense is for read, dense2 is for write
    public var dense = [ComponentEntry<T>]()
    public var dense2 = [ComponentEntry<T>]()
    public var double_buffered : Bool { return true }

    public init(capacity : Int = 512){
        self.dense.reserveCapacity(capacity)
        self.dense2.reserveCapacity(capacity)
    }

    @inline(__always)
    public var count : Int { get { return dense.count} }

    @inline(__always)
    public func get_dense() -> [ComponentEntry<T>] {
        return dense
    }

    @inline(__always)
    public func get_direct(_ denseIndex : DenseIndex ) -> ComponentEntry<T> {
        return dense[denseIndex]
    }

    @inline(__always)
    public func set_direct(_ denseIndex : DenseIndex, _ entry : ComponentEntry<T>){
        dense2[denseIndex] = entry
    }

    @inline(__always)
    public func remove_direct(_ denseIndex:DenseIndex){
        dense[denseIndex].entity = ENTITY_EMPTY
        dense2[denseIndex].entity = ENTITY_EMPTY
    }

    @inline(__always)
    public func add_direct(_ ce : ComponentEntry<T>) -> Int {
        let denseIndex = dense.count
        dense.append( ce )
        dense2.append( ce )
        return denseIndex
    }

    @inline(__always)
    public func upkeep(deleted:Int) -> Bool {
        swap(&dense, &dense2)

        guard deleted > 0 && dense.count / deleted < 3 else { return false }
        // exploit that ENTITY_EMPTY is biggest number
        dense.sort(by:{ $0.entity < $1.entity})
        dense.removeLast(deleted)
        dense2.removeLast(deleted)
        dense2.withUnsafeMutableBufferPointer { dest in
            for i in 0..<dense.count {
                dense2[i] = dense[i]
            }
        }
        return true
    }
}