open Graph
open Tools

type flow = {
  flow: int;
  capacity: int;
}

type initial_graph = flow graph;;
type redisual_graph = int graph;;

let reset_graph graph = e_fold graph (fun gr arc -> new_arc gr {arc with lbl = {arc.lbl with flow = 0}}) (clone_nodes graph);;

let flow_to_residual graph =
  let residual_graph = clone_nodes graph in 
    let add_double_arc gr arc = 
      add_arc (add_arc gr arc.src arc.tgt arc.lbl.capacity) arc.tgt arc.src 0 in
    e_fold graph add_double_arc residual_graph;;

let arc_list_includes l arc = List.exists (fun other -> other.src == arc.src && other.tgt == arc.tgt) l;;

let find_path residual_graph src tgt =
  let rec find_next_arc source memo = 
    let possible_arcs = List.filter (fun arc -> arc.lbl > 0 && not (arc_list_includes memo arc)) (out_arcs residual_graph source) in
      if List.length possible_arcs == 0 then None else match (List.find_opt (fun a -> a.tgt == tgt) possible_arcs) with
      | Some final_arc -> Some (List.rev (final_arc :: memo))
      | None -> List.find_map (fun a -> find_next_arc a.tgt (a :: memo)) possible_arcs
  in find_next_arc src [];;

let get_path_min_augmentation path = 
  List.fold_left min max_int (List.map (fun a -> a.lbl) path);;

let update_augmentations gr path aug = 
  let add_augmentation_to_arc graph arc = 
    add_arc (add_arc graph arc.src arc.tgt (-aug)) arc.tgt arc.src aug;
  in List.fold_left add_augmentation_to_arc gr path;;

let residual_to_flow initial residual =
  let update_initial_arc_from_residual initial_graph initial_arc = 
    match (find_arc residual initial_arc.src initial_arc.tgt) with
    | None -> initial_graph
    | Some residual_arc -> new_arc initial_graph {
        initial_arc with lbl = {
          initial_arc.lbl with flow = max (initial_arc.lbl.capacity - residual_arc.lbl) 0
          }
        };
  in e_fold initial (update_initial_arc_from_residual) initial;;

let apply_ford_fulkerson initial src tgt =
  let maxflow = ref 0 in 
  let residual_graph = flow_to_residual (reset_graph initial) in
    let rec loop current_graph =
      match (find_path current_graph src tgt) with
      | None -> Printf.printf "could not find path, ending algorithm, maximum flow: %d\n" !maxflow ; current_graph
      | Some path -> 
        Printf.printf "found path: ";
        List.iter (fun arc -> Printf.printf "%d -> " arc.src) path;
        Printf.printf "%d\nfinding min augment\n" tgt;
        let min_aug = get_path_min_augmentation path in
          maxflow := min_aug + !maxflow;
          Printf.printf "found min augment: %d\n" min_aug;
          let updated_graph = update_augmentations current_graph path min_aug in
            loop updated_graph;
      in 
      let final_residual_graph = loop residual_graph in
        residual_to_flow (reset_graph initial) final_residual_graph;;

let printable_flow_graph graph =
  gmap graph (fun arc -> {arc with lbl = Printf.sprintf "%d/%d" arc.lbl.flow arc.lbl.capacity});;

let flow_from_string_graph graph =
  gmap graph (fun arc -> {arc with lbl = {flow = 0; capacity = int_of_string arc.lbl}});;