open Graph


(* we fold the graph using new_node as the function, 
   and using empty_graph as the initial value*)
let clone_nodes (graph: 'a graph) = n_fold graph (fun x -> new_node x) empty_graph;;

(* we clone the graph, then fold the old graph, mapping the arcs, 
   and using the new cloned graph as the initial value *)
let gmap graph f = 
  let new_graph = clone_nodes graph
  in e_fold graph (fun old_graph old_arc -> new_arc old_graph (f old_arc)) new_graph;;

let add_arc graph src tgt value = 
   match (find_arc graph src tgt) with 
      | None -> new_arc graph {src; tgt; lbl = value};
      | Some arc -> new_arc graph {arc with lbl = arc.lbl + value};;

