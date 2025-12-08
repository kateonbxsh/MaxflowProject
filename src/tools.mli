open Graph

val clone_nodes: 'a graph -> 'b graph
val gmap: 'a graph -> ('a arc -> 'b arc) -> 'b graph
val add_arc: int graph -> id -> id -> int -> int graph

