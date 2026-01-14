open Graph
open Algo

(** Airline scheduling module *)

(** Flight record *)
type flight = {
  id: int;
  departure_airport: string;
  arrival_airport: string;
  departure_time: int;  (** in minutes *)
  arrival_time: int;    (** in minutes *)
}

type schedule_arc = {
  from_airport: string;
  to_airport: string;
  flow: int;
}

val graph_to_schedule: bounded_flow graph -> flight list -> schedule_arc list

val airline_schedule : flight list -> int -> bounded_flow graph option
val export_schedule : string -> bounded_flow Graph.graph -> flight list -> unit
val export_schedule_text : string -> bounded_flow Graph.graph -> flight list -> unit
val read_flights_from_file : string -> flight list
