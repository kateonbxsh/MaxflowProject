open Graph

(* we fold the graph using new_node as the function, 
and using empty_graph as the initial value*)
let clone_nodes (graph: 'a graph) = n_fold graph (fun x -> new_node x) empty_graph;;

(* we clone the graph, then fold the old graph, mapping the arcs, 
and using the new cloned graph as the initial value *)
let gmap graph f = 
  let new_graph = clone_nodes graph
    in e_fold graph (fun old_graph old_arc -> new_arc old_graph (f old_arc)) new_graph;;



(* new_arc already does the job (thanks prof for pointing it out)*)
let add_arc graph fromid toid value = 
  new_arc graph {src = fromid; tgt = toid; lbl = value }

