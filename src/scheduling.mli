open Graph

type flight = {
  id: int;
  departure_airport: string;
  arrival_airport: string;
  departure_time: int;
  arrival_time: int;
  flight_number: string;
}

type bounded_flow = {
  mutable flow: int;
  lower: int;
  capacity: int;
}

type schedule_arc = {
  from_airport: string;
  to_airport: string;
  flow: int;
}

val airline_schedule : flight list -> int -> bounded_flow graph option
val graph_to_schedule : bounded_flow graph -> flight list -> schedule_arc list 
val export_schedule : string -> bounded_flow graph -> flight list -> unit
val export_schedule_graph : string -> bounded_flow graph -> flight list -> unit
val read_flights_from_file : string -> flight list
