
// pipe operator
// baz |> bar |> foo is equivalent to foo(bar(baz)
infix operator |> : AdditionPrecedence
func |> <T,U>(value:T, function: (T)->U) -> U { return function(value) }

// spent time implementing lazy iterators for nuthin
/*
struct MyFilterIterator<T>: Sequence, IteratorProtocol {
    private var seq: any IteratorProtocol<T>
    private var filterFn: (T) -> Bool

    init(_ seq: any IteratorProtocol<T>,_ filterFn : @escaping (T) -> Bool) {
        self.seq = seq
        self.filterFn = filterFn
    }

    mutating func next() -> T? {
    	var el : T?
    	while true {
    		el = seq.next()
			if el == nil { return nil }
			if filterFn(el!){ return el }
		}
		return nil
    }
}

struct MyMapIterator<T,U>: Sequence, IteratorProtocol {
    private var seq: any IteratorProtocol<T>
    private var mapFn: (T) -> U

    init(_ seq: any IteratorProtocol<T>,_ mapFn : @escaping (T) -> U) {
        self.seq = seq
        self.mapFn = mapFn
    }

    mutating func next() -> U? {
    	var el : T?
    	while true {
			el = seq.next()
			if el == nil { return nil }
			return mapFn(el!)
		}
		return nil
    }
}

struct MyZipIterator<T,U>: Sequence, IteratorProtocol {
    private var seqT: any IteratorProtocol<T>
    private var seqU: any IteratorProtocol<U>

    init(_ seqT: any IteratorProtocol<T>,_ seqU: any IteratorProtocol<U>) {
        self.seqT = seqT
        self.seqU = seqU
    }

    mutating func next() -> (T, U)? {
    	var elT : T?
    	var elU : U?
    	while true {
			elT = seqT.next()
			elU = seqU.next()
			if elT == nil || elU == nil { return nil }
			return (elT!,elU!)
		}
		return nil
    }
}

extension IteratorProtocol  {

	func filterIt(_ filterFn: @escaping (Element) -> Bool) -> MyFilterIterator<Element> {
        return MyFilterIterator(self, filterFn)
    }
    func mapIt<U>(_ mapFn: @escaping (Element) -> U) -> MyMapIterator<Element,U> {
        return MyMapIterator(self, mapFn)
    }
    func zipIt<U>(_ seqU: any IteratorProtocol<U>) -> MyZipIterator<Element,U> {
        return MyZipIterator(self, seqU)
    }
}
*/