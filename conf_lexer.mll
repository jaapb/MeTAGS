{
	open Lexing
	open Conf_parser

	exception SyntaxError of string
	
	let next_line lexbuf =
  let pos = lexbuf.lex_curr_p in
  lexbuf.lex_curr_p <-
    { pos with pos_bol = lexbuf.lex_curr_pos;
               pos_lnum = pos.pos_lnum + 1
    }
}

rule token = parse
| [' ' '\t' ] { token lexbuf }
| '\n' { next_line lexbuf; token lexbuf }
| ['0'-'9']+ as n { NUMBER (int_of_string n) }
| '"' ([^'"']* as s) '"' { STRING s }
| '-' { HYPHEN }
| ',' { COMMA }
| '(' { LPAREN }
| ')' { RPAREN }
| "turn" { TURN }
| "phase" { PHASE }
| "name" { NAME }
| "duration" { DURATION }
| "foreground" { FOREGROUND_COLOUR }
| "background" { BACKGROUND_COLOUR }
| "image" { IMAGE }
| "rgb" { RGB }
| eof	{ EOF }
| _ { raise (SyntaxError (Printf.sprintf "At offset %d: unexpected character.\n" (Lexing.lexeme_start lexbuf))) }

