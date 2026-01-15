open Graph
open Algo
open Tools

type flight = {
  id: int;
  departure_airport: string;
  arrival_airport: string;
  departure_time: int;
  arrival_time: int;
  flight_number: string;
}

let date_to_minutes s = Scanf.sscanf s "%02d:%02d" (fun h m -> h * 60 + m);;
let minutes_to_date m = Printf.sprintf "%02d:%02d" (m / 60) (m mod 60);;

let read_flights_from_file path : flight list =
  let ic = open_in path in
  let flights = ref [] in
  let id_counter = ref 0 in

  try
    while true do
      let line = input_line ic in
      let line = String.trim line in
      if line <> "" then begin
        try
          (* AIRPORT -> AIRPORT | HH:MM -> HH:MM *)
          Scanf.sscanf line "%s -> %s | %s -> %s | %s"
            (fun departure_airport arrival_airport deptime arrtime flight_number ->
              let dep_time = date_to_minutes deptime in
              let arr_time = date_to_minutes arrtime in
              let f = { id = !id_counter;
                        departure_airport;
                        arrival_airport;
                        departure_time = dep_time;
                        arrival_time = arr_time;
                        flight_number } in
              flights := f :: !flights;
              id_counter := !id_counter + 1
            )
        with
        | Scanf.Scan_failure msg
        | Failure msg ->
            failwith (Printf.sprintf "Failed to parse line: '%s', error: %s" line msg)
      end
    done;
    []
  with End_of_file ->
    close_in ic;
    List.rev !flights

(* two flights are compatible if they are 30 mins away from each other *)
let compatible f1 f2 =
  f1.arrival_airport = f2.departure_airport &&
  (f1.arrival_time + 30 mod (24 * 60)) <= f2.departure_time

let s = 0
let t = 1
let si i = 2 + 2*i
let di i = 2 + 2*i + 1

let is_si i = i mod 2 == 0;;
let is_di i = i mod 2 == 1;;

type bounded_flow = {
  mutable flow: int;
  lower: int;
  capacity: int;
}

(* Build the bounded flow graph *)
let build_bounded_graph (flights: flight list) (k: int) : bounded_flow graph =

  let g = empty_graph in
  let g = new_node g s in
  let g = new_node g t in

  (* Add flight nodes *)
  let g =
    List.fold_left (fun g f ->
      let g = new_node g (si f.id) in
      let g = new_node g (di f.id) in
      g
    ) g flights
  in

  (* Helper to add bounded edge *)
  let add_arc g u v lower upper =
    let lbl = {flow=0; lower=lower; capacity=upper} in
    new_arc g {src=u; tgt=v; lbl}
  in

  (* s -> si [0,1] *)
  let g = List.fold_left (fun g f -> add_arc g s (si f.id) 0 1) g flights in
  (* si -> di [1,1] *)
  let g = List.fold_left (fun g f -> add_arc g (si f.id) (di f.id) 1 1) g flights in
  (* di -> t [0,1] *)
  let g = List.fold_left (fun g f -> add_arc g (di f.id) t 0 1) g flights in
  (* di -> sj [0,1] if compatible *)
  let g =
    List.fold_left (fun g f1 ->
      List.fold_left (fun g f2 ->
        if compatible f1 f2 then add_arc g (di f1.id) (si f2.id) 0 1
        else g
      ) g flights
    ) g flights
  in
  (* s -> t [0, k] *)
  let g = add_arc g s t 0 k in
  g


(* compute and returns demands from lower bounds *)
let compute_demands (g: bounded_flow graph) (k: int): int array =
  let n = n_fold g (fun acc id -> max acc id) 0 + 1 in
  let demand = Array.make n 0 in
  demand.(s) <- (-k);
  demand.(t) <- (k);
  e_iter g (fun arc ->
    demand.(arc.src) <- demand.(arc.src) + arc.lbl.lower;
    demand.(arc.tgt) <- demand.(arc.tgt) - arc.lbl.lower
  );
  demand

let add_super_nodes g demand: bounded_flow graph * id * id * int =
  let n = Array.length demand in
  let ss = n in
  let tt = n + 1 in
  let g = new_node g ss in
  let g = new_node g tt in

  let (g, total_demand) =
    Array.fold_left (fun (g, total) v ->
      let d = demand.(v) in
      if d < 0 then
        (new_arc g {src=ss; tgt=v; lbl={flow=0; lower=0; capacity=(-d)}}, total)
      else if d > 0 then
        (new_arc g {src=v; tgt=tt; lbl={flow=0; lower=0; capacity=(d)}}, total + d)
      else
        (g, total)
    ) (g, 0) (Array.init n (fun i -> i))
  in

  (g, ss, tt, total_demand)

(* recover original flows by adding lower bounds back *)
let recover_flows (g: bounded_flow graph) (flowg: flow graph) : unit =
  e_iter flowg (fun arc ->
    match(find_arc g arc.src arc.tgt) with
    | None -> ();
    | Some barc -> barc.lbl.flow <- arc.lbl.flow + barc.lbl.lower
  )

type schedule_arc = {
  from_airport: string;
  to_airport: string;
  flow: int;
}

let graph_to_schedule (g: bounded_flow graph) flights : schedule_arc list =
  e_fold g (fun acc arc ->
    if arc.lbl.flow > 0 then
      let f_from = List.find_opt (fun f -> si f.id = arc.src || di f.id = arc.src) flights in
      let f_to = List.find_opt (fun f -> si f.id = arc.tgt || di f.id = arc.tgt) flights in
      match f_from, f_to with
      | Some ff, Some ft ->
          {from_airport=ff.arrival_airport; to_airport=ft.departure_airport; flow=arc.lbl.flow} :: acc
      | _ -> acc
    else acc
  ) []


let airline_schedule flights k : bounded_flow graph option =

  let g = build_bounded_graph flights k in

  let demand = compute_demands g k in

  (* add SS and TT *)
  let (g, ss, tt, total_demand) = add_super_nodes g demand in

  let flow_g = e_fold g (fun org a -> new_arc org {src=a.src; tgt=a.tgt; lbl={flow=a.lbl.flow; capacity=a.lbl.capacity}}) (clone_nodes g) in

  let flow_g = apply_ford_fulkerson flow_g ss tt in

  (* check if demand is satisfied (sum of all flows going out of SS) *)
  let total_flow_out_ss = 
    let arcs = out_arcs flow_g ss in
      List.fold_left (fun acc (arc: flow arc) -> acc + arc.lbl.flow) 0 arcs
  in

  recover_flows g flow_g;

  Printf.printf "total flow out of SS %d, total demand %d\n" total_flow_out_ss total_demand;

  if total_flow_out_ss <> total_demand then None
  else begin
    Some g
  end;;

let export_schedule_graph path (g: bounded_flow graph) flights =
  let ff = open_out path in

  Printf.fprintf ff "digraph airline_schedule {\n";
  Printf.fprintf ff "  fontname=\"Helvetica,Arial,sans-serif\";\n";
  Printf.fprintf ff "  node [fontname=\"Helvetica,Arial,sans-serif\"];\n";
  Printf.fprintf ff "  edge [fontname=\"Helvetica,Arial,sans-serif\"];\n";
  Printf.fprintf ff "  rankdir=LR;\n";
  Printf.fprintf ff "  node [shape=square];\n";

  (* grab flight from sid *)
  let flight_of_sid id =
    List.find_opt (fun f -> si f.id = id) flights

  in


  let n = n_fold g (fun a _ -> a + 1) 0 in
  let ss = n - 2 in
  let tt = n - 1 in

  (* Keep track of which arcs were already used in a path *)
  let used = Hashtbl.create 100 in

  (* Find next arc with positive flow and not used *)
  let next_arc_from v =
    List.find_opt (fun (arc: bounded_flow arc) ->
      arc.lbl.flow > 0 && not (Hashtbl.mem used (arc.src, arc.tgt)) &&
      not (List.mem arc.src [ss; tt]) &&
      not (List.mem arc.tgt [ss; tt; t])
    ) (out_arcs g v)
  in

  (* Trace one airplane path starting from s *)
  let rec trace_airplane path_nodes current =
    match next_arc_from current with
    | None -> List.rev path_nodes
    | Some arc ->
        Hashtbl.add used (arc.src, arc.tgt) ();
        trace_airplane (arc :: path_nodes) arc.tgt
  in

  let airplane_counter = ref 1 in

  let airplane_initial_flights = ref [] in 

  (* generate all airplane paths *)
  let rec trace_all v =
    match next_arc_from v with
    | None -> ()
    | Some _ ->
        let path = trace_airplane [] v in

        let rec print_path = function
          | [] -> ()
          | (arc: bounded_flow arc) :: rest ->
              let airplane = !airplane_counter in

              if arc.src = s then
                match flight_of_sid arc.tgt with
                | Some flight -> airplane_initial_flights := (airplane, flight) :: !airplane_initial_flights
                | None -> ()
              else if is_si arc.src && is_di arc.tgt then begin
                match flight_of_sid arc.src with
                  | Some flight -> Printf.fprintf ff "  \"%s\" -> \"%s\" [label=\"%s\"];\n" 
                    flight.departure_airport
                    flight.arrival_airport
                    (Printf.sprintf "a%d (%s)" airplane flight.flight_number) 
                  | None -> ();
              end;

              print_path rest
        in
        print_path path;
        airplane_counter := !airplane_counter + 1;
        trace_all v
  in

  trace_all s;
  (* print airplane nodes*)
  Printf.fprintf ff "  node [shape=circle];\n";
  List.iter (fun (airplane, flight) -> Printf.fprintf ff "  \"a%d\" -> \"%s\";\n" airplane flight.departure_airport) !airplane_initial_flights;
  Printf.fprintf ff "\n}\n";
  close_out ff

let export_schedule path (g: bounded_flow graph) flights =
  let ff = open_out path in

  (* grab flight from sid *)
  let flight_of_sid id =
    List.find_opt (fun f -> si f.id = id) flights

  in


  let n = n_fold g (fun a _ -> a + 1) 0 in
  let ss = n - 2 in
  let tt = n - 1 in

  (* Keep track of which arcs were already used in a path *)
  let used = Hashtbl.create 100 in

  (* Find next arc with positive flow and not used *)
  let next_arc_from v =
    List.find_opt (fun (arc: bounded_flow arc) ->
      arc.lbl.flow > 0 && not (Hashtbl.mem used (arc.src, arc.tgt)) &&
      not (List.mem arc.src [ss; tt]) &&
      not (List.mem arc.tgt [ss; tt; t])
    ) (out_arcs g v)
  in

  (* Trace one airplane path starting from s *)
  let rec trace_airplane path_nodes current =
    match next_arc_from current with
    | None -> List.rev path_nodes
    | Some arc ->
        Hashtbl.add used (arc.src, arc.tgt) ();
        trace_airplane (arc :: path_nodes) arc.tgt
  in

  let airplane_counter = ref 1 in

  (* generate all airplane paths *)
  let rec trace_all v =
    match next_arc_from v with
    | None -> ()
    | Some _ ->
        let path = trace_airplane [] v in

        let rec print_path = function
          | [] -> ()
          | (arc: bounded_flow arc) :: rest ->
              let airplane = !airplane_counter in

              if arc.src = s then

                let airport =
                  match flight_of_sid arc.tgt with
                  | Some f -> f.departure_airport
                  | None -> "?"
                in
                Printf.fprintf ff
                  "Airplane %d starts at airport %s\n"
                  airplane airport

              else if is_di arc.src && is_si arc.tgt then
                (* Case 2: waits *)
                match flight_of_sid arc.tgt with
                  | Some next_flight -> Printf.fprintf ff
                  "Airplane %d waits at airport %s for flight %s at %s\n"
                  airplane next_flight.departure_airport next_flight.flight_number (minutes_to_date next_flight.departure_time) 
                  | None -> ();

              else begin
                match flight_of_sid arc.src with
                  | Some flight -> Printf.fprintf ff
                      "Airplane %d: %s -> %s (%s)\n"
                      airplane flight.departure_airport flight.arrival_airport flight.flight_number;
                    if rest = [] then begin
                    Printf.fprintf ff
                      "Airplane %d schedule ends at airport %s\n"
                      airplane flight.arrival_airport;
                    end;
                  | None -> ();
              end;

              print_path rest

        in
        print_path path;
        Printf.fprintf ff "\n";
        airplane_counter := !airplane_counter + 1;
        trace_all v
  in

  trace_all s;
  close_out ff