open Graph

type flow = {
  flow: int;
  capacity: int;
};;

type initial_graph = flow graph;;
type redisual_graph = int graph;;

val apply_ford_fulkerson: flow graph -> int -> int -> flow graph;;
val printable_flow_graph: flow graph -> string graph;;
val flow_from_string_graph: string graph -> flow graph;;