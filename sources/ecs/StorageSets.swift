

//typealias DenseIndex = Int
//typealias ComponentEntry<T:Component> = (entity:Entity, component:T)

// Compiles but trying to use it in ComponentStorage doesn't
// protocol can't upcast/downcast C type into generic T type..?

protocol StorageSet {
    associatedtype C : Component

    var count : Int { get }
    func get_dense() -> [ComponentEntry<C>]
    func upkeep(deleted:Int) -> Bool

    func get_direct(_ denseIndex : DenseIndex ) -> ComponentEntry<C>
    func set_direct(_ denseIndex : DenseIndex, _ entry : ComponentEntry<C>)
    func remove_direct(_ denseIndex:DenseIndex)
    func add_direct(_ ce : ComponentEntry<C>) -> Int
} 


class SimpleSet<T : Component> : StorageSet {
    typealias C = T

    public var dense = [ComponentEntry<T>]()
    public var doubleBuffered : Bool { return false }

    public init(capacity : Int = 512){
        self.dense.reserveCapacity(capacity)
    }

    public var count : Int { get { return dense.count} }

    public func get_dense() -> [ComponentEntry<T>] {
        return dense
    }

    public func get_direct(_ denseIndex : DenseIndex ) -> ComponentEntry<T> {
        return dense[denseIndex]
    }

    public func set_direct(_ denseIndex : DenseIndex, _ entry : ComponentEntry<T>){
        dense[denseIndex] = entry
    }

    public func remove_direct(_ denseIndex:DenseIndex){
        dense[denseIndex].entity = ENTITY_EMPTY
    }

    public func add_direct(_ ce : ComponentEntry<T>) -> Int {
        let denseIndex = dense.count
        dense.append( ce )
        return denseIndex
    }

    public func upkeep(deleted:Int) -> Bool {
        guard dense.count / deleted < 3 else { return false }

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
    public var doubleBuffered : Bool { return true }

    public init(capacity : Int = 512){
        self.dense.reserveCapacity(capacity)
        self.dense2.reserveCapacity(capacity)
    }

    public var count : Int { get { return dense.count} }

    public func get_dense() -> [ComponentEntry<T>] {
        return dense
    }

    public func get_direct(_ denseIndex : DenseIndex ) -> ComponentEntry<T> {
        return dense[denseIndex]
    }

    public func set_direct(_ denseIndex : DenseIndex, _ entry : ComponentEntry<T>){
        dense2[denseIndex] = entry
    }

    public func remove_direct(_ denseIndex:DenseIndex){
        dense[denseIndex].entity = ENTITY_EMPTY
        dense2[denseIndex].entity = ENTITY_EMPTY
    }

    public func add_direct(_ ce : ComponentEntry<T>) -> Int {
        let denseIndex = dense.count
        dense.append( ce )
        dense2.append( ce )
        return denseIndex
    }

    public func upkeep(deleted:Int) -> Bool {
        swap(&dense, &dense2)

        guard dense.count / deleted < 3 else { return false }
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