open Gfile
open Algo
open Printf
open Unix
open Scheduling

let () =
  if Array.length Sys.argv < 2 then begin
    printf "Usage:\n";
    printf "  %s flow infile source sink outfile [svgfile]\n" Sys.argv.(0);
    printf "  %s scheduling infile crew_count outfile [svgfile]\n" Sys.argv.(0);
    exit 1
  end;

  let mode = Sys.argv.(1) in

  if mode = "flow" then begin
    if Array.length Sys.argv < 6 then begin
      printf "Usage: %s flow infile source sink outfile [svgfile]\n" Sys.argv.(0);
      exit 1
    end;

    let infile  = Sys.argv.(2) in
    let source  = int_of_string Sys.argv.(3) in
    let sink    = int_of_string Sys.argv.(4) in
    let outfile = Sys.argv.(5) in
    let svgfile =
      if Array.length Sys.argv >= 7 then Some Sys.argv.(6) else None
    in

    let graph = from_file infile in
    let result = apply_ford_fulkerson (flow_from_string_graph graph) source sink in
    export outfile (printable_flow_graph result);

    (match svgfile with
     | Some f -> ignore (system (sprintf "dot -Tsvg %s -o %s" outfile f))
     | None -> ());

  end
  else if mode = "scheduling" then begin
    if Array.length Sys.argv < 5 then begin
      printf "Usage: %s scheduling infile crew_count outfile [svgfile]\n" Sys.argv.(0);
      exit 1
    end;

    let infile = Sys.argv.(2) in
    let airplanes_count = int_of_string Sys.argv.(3) in
    let outfile = Sys.argv.(4) in
    let svgfile =
      if Array.length Sys.argv >= 6 then Some Sys.argv.(5) else None
    in

    let flights = read_flights_from_file infile in

    printf "Read %d flights, %d airplanes available\n" (List.length flights) airplanes_count;

    match airline_schedule flights airplanes_count with
    | None ->
        printf "No feasible schedule found.\n";
        exit 1
    | Some g ->
        export_schedule_graph (outfile ^ ".txt") g flights;
        export_schedule (outfile ^ ".schedule") g flights;

        (match svgfile with
         | Some f ->
             export_schedule (outfile ^ ".dot") g flights;
             ignore (system (sprintf "dot -Tsvg %s.dot -o %s" outfile f))
         | None -> ())
  end
  else begin
    printf "Unknown mode: %s\n" mode;
    exit 1
  end
