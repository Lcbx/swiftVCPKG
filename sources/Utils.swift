
// pipe operator
// baz |> bar |> foo is equivalent to foo(bar(baz)
infix operator |> : AdditionPrecedence
func |> <T,U>(value:T, function: (T)->U) -> U { return function(value) }
