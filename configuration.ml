open Conf_types
open Conf_lexer
open Lexing

let turns = ref [| |]

let print_position outx lexbuf =
  let pos = lexbuf.lex_curr_p in
  Printf.fprintf outx "%s:%d:%d" pos.pos_fname
    pos.pos_lnum (pos.pos_cnum - pos.pos_bol + 1)

let parse_with_error lexbuf =
  try Conf_parser.configuration Conf_lexer.token lexbuf with
  | SyntaxError msg ->
    Printf.fprintf stderr "%a: %s\n" print_position lexbuf msg;
		None
  | Conf_parser.Error ->
    Printf.fprintf stderr "%a: syntax error\n" print_position lexbuf;
    exit (-1)

let rec parse_and_print lexbuf =
  match parse_with_error lexbuf with
  | Some value ->
			turns := value
  | None -> ()

let read_from_file f =
	Printf.eprintf "starting configuration...\n%!";
	let ch = open_in f in
	let lexbuf = Lexing.from_channel ch in
	lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = f };
	parse_and_print lexbuf;
	close_in ch

