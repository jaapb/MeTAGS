%start <Conf_types.configuration option> configuration
%type <int list> range
%type <(int * Conf_types.turn) list> turn_specification
%type <string> name
%type <Conf_types.colour_spec> foreground_colour
%type <Conf_types.colour_spec> background_colour

%token TURN
%token PHASE
%token <int> NUMBER 
%token HYPHEN
%token COMMA
%token BACKGROUND_COLOUR
%token FOREGROUND_COLOUR
%token IMAGE
%token NAME
%token <string> STRING
%token RPAREN LPAREN
%token RGB
%token EOF
%token DURATION

%{
open Conf_types

module OrdString =
struct
	type t = string
	let compare = String.compare
end
module StringSet = Set.Make(OrdString)

let range_from_to s e =
	if e < s then []
	else if e = s then [s]
	else
	begin
		let res = ref [] in
		for i = e downto s
		do
			res := i::!res
		done;
		List.rev !res
	end

let default_background = ref `BLACK
let default_foreground = ref `WHITE
let default_image = ref None

let default_turn =
	{ name = None;
		phases = [| |]
	}
	
let default_phase () =
	{ background_colour = !default_background;
		foreground_colour = !default_foreground;
		image = !default_image;
		name = None;
		duration = 0;
	}

let do_turn_command old_t old_p = function
| `Background_colour c -> (old_t, { old_p with background_colour = c })
| `Foreground_colour c -> (old_t, { old_p with foreground_colour = c })
| `Image i -> (old_t, { old_p with image = Some i })
| `Name n -> ({ old_t with name = Some n }, old_p)
| `Duration d -> (old_t, { old_p with duration = d })
| _ -> raise (Invalid_argument "Unknown turn command")


let do_phase_command old = function
| `Background_colour c -> { old with background_colour = c }
| `Foreground_colour c -> { old with foreground_colour = c }
| `Image i -> { old with image = Some i }
| `Name n -> { old with name = Some n }
| `Duration d -> { old with duration = d }
| _ -> raise (Invalid_argument "Unknown phase command")

%}

%%

configuration:
	general_configuration
	ts = turn_specification+
	EOF
	{ let l = List.flatten ts in
		let max = List.fold_left (fun acc (i, _) -> max i acc) 0 l in
		let res = Array.init max (fun i -> None) in
		List.iter (fun (i, p) -> res.(i - 1) <- Some p) l;
		let images = ref StringSet.empty in
		Array.iter (function
		| None -> ()
		| Some t -> Array.iter (fun p ->
			match p.image with
			| None -> ()
			| Some i -> images := StringSet.add i !images 
			) t.phases
		) res;	
		let turns = Array.mapi (fun i p -> match p with
			| None -> raise (Failure (Printf.sprintf "turn %d not specified" (i+1)))
			| Some x -> x) res in
		Some { turns = turns ; images = StringSet.elements !images }
	}
	
general_configuration:
	general_command* { }
	
general_command:
|	c = background_colour { default_background := c }
| c = foreground_colour { default_background := c }
| i = image { default_image := Some i }

turn_specification:
	TURN r = range 
	t = turn_command*
	ps = phase_specification*
	{ let (turn, default_turn_phase) = List.fold_left (fun (acc_t, acc_p) c ->
			do_turn_command acc_t acc_p c
		) (default_turn, default_phase ()) t in 
		let l = List.flatten ps in
		let max = List.fold_left (fun acc (i, _) -> max i acc) 1 l in
		let res = Array.init max (fun i -> default_turn_phase) in
		List.iter (fun (i, p) -> 
			res.(i - 1) <-  List.fold_left (fun acc c -> 
				do_phase_command acc c	
			) res.(i - 1) p
		) l;
		List.rev_map (fun i ->
			i, { turn with phases = res }
		) r
	}

turn_command:
| c = background_colour { `Background_colour c }
| c = foreground_colour { `Foreground_colour c }
| i = image { `Image i }
| n = name { `Name n }
| d = duration { `Duration d }

phase_specification:
	PHASE r = range 
	p = phase_command*
	{ List.rev_map (fun i -> i, p) r
	}

phase_command:
| c = background_colour { `Background_colour c }
| c = foreground_colour { `Foreground_colour c }
| i = image { `Image i }
| n = name { `Name n }
| d = duration { `Duration d }

range:
| n = NUMBER { [n] }
| n_start = NUMBER HYPHEN n_end = NUMBER { range_from_to n_start n_end }
| r1 = range COMMA r2 = range { r1 @ r2 }

background_colour:
| BACKGROUND_COLOUR s = colour_spec { s }

foreground_colour:
| FOREGROUND_COLOUR s = colour_spec { s }

image:
| IMAGE f = STRING { f }

name:
| NAME n = STRING { n }

duration:
| DURATION d = NUMBER { d }

colour_spec:
| n = STRING { `NAME n }
| RGB LPAREN r = NUMBER COMMA g = NUMBER COMMA b = NUMBER RPAREN { `RGB (r, g, b) }
