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
%token NAME
%token <string> STRING
%token RPAREN LPAREN
%token RGB
%token EOF
%token DURATION

%{
open Conf_types

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

let default_phase () =
	{ background_colour = !default_background;
		foreground_colour = !default_foreground;
		name = None;
		duration = 0;
	}

let do_phase_command old = function
| `Background_colour c -> { old with background_colour = c }
| `Foreground_colour c -> { old with foreground_colour = c }
| `Name n -> { old with name = Some n }
| `Duration d -> { old with duration = d }
| _ -> raise (Invalid_argument "Unknown command")

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
		Some (Array.mapi (fun i p -> match p with
			| None -> raise (Failure (Printf.sprintf "turn %d not specified" (i+1)))
			| Some x -> x) res)	
	}
	
general_configuration:
	general_command* { }
	
general_command:
|	c = background_colour { default_background := c }
| c = foreground_colour { default_background := c }

turn_specification:
	TURN r = range 
	t = turn_command*
	ps = phase_specification*
	{ let default_turn_phase = List.fold_left (fun acc c ->
			do_phase_command acc c
		) (default_phase ()) t in 
		let l = List.flatten ps in
		let max = List.fold_left (fun acc (i, _) -> max i acc) 1 l in
		let res = Array.init max (fun i -> default_turn_phase) in
		List.iter (fun (i, p) -> 
			res.(i - 1) <-  List.fold_left (fun acc c -> 
				do_phase_command acc c	
			) res.(i - 1) p
		) l;
		List.rev_map (fun i ->
			i, { phases = res }
		) r
	}

turn_command:
| c = background_colour { `Background_colour c }
| c = foreground_colour { `Foreground_colour c }
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

name:
| NAME n = STRING { n }

duration:
| DURATION d = NUMBER { d }

colour_spec:
| n = STRING { `NAME n }
| RGB LPAREN r = NUMBER COMMA g = NUMBER COMMA b = NUMBER RPAREN { `RGB (r, g, b) }
