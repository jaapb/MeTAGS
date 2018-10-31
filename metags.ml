open GdkKeysyms
open Arg

open Configuration

let current_turn = ref 0
let current_phase = ref 0
let timer_mins = ref 0
let timer_secs = ref 0
let the_end = ref false

let timer = ref None

let full_screen = ref false
let file_names = ref []

let arg_spec =
	["-fs", Unit (fun () -> full_screen := true), "Full screen"]

let name_of_turn t =
	match !turns.(t).name with
	| None -> ""
	| Some x -> Printf.sprintf " (%s)" x
	
let name_of_phase t i =
	match !turns.(t).phases.(i).name with
	| None -> Printf.sprintf "phase %d" (i + 1)
	| Some x -> x

let new_phase a dr =
	let phase = !turns.(!current_turn).phases.(!current_phase) in
	let (bg: GDraw.color) = phase.background_colour in
	let (fg: GDraw.color) = phase.foreground_colour in
	timer_mins := phase.duration;
	timer_secs := 0;
	a#misc#modify_bg [`NORMAL, bg; `ACTIVE, bg; `PRELIGHT, bg; `INSENSITIVE, bg; `SELECTED, bg];
	dr#set_background bg;
	dr#set_foreground fg

let advance_phase a dr =
	incr current_phase;
	if !current_phase >= Array.length !turns.(!current_turn).phases then
	begin
		incr current_turn;
		if !current_turn >= Array.length !turns then
		begin
			current_turn := 0;
			the_end := true
		end;
		current_phase := 0;
	end;
	new_phase a dr

let stop_timer () =
	match !timer with
	| None -> ()
	| Some t -> GMain.Timeout.remove t; timer := None

let start_timer w a dr =
	timer := Some (GMain.Timeout.add ~ms:1000 ~callback:(fun () ->
		decr timer_secs;
		if !timer_secs <= 0 then
		begin
			if !timer_mins <= 0 then
				advance_phase a dr
			else
			begin
				decr timer_mins;
				timer_secs := 59
			end
		end;
		GtkBase.Widget.queue_draw w#as_widget;
		true))

let reset_timer w a dr =
	stop_timer ();
	start_timer w a dr

let keypress w a dr ev =
	let key = GdkEvent.Key.keyval ev in
	if key = _Escape then
	begin
		GtkMain.Main.quit ();
		exit 0
	end
	else if key = _Page_Down then
	begin
		advance_phase a dr;
		reset_timer w;
		GtkBase.Widget.queue_draw w#as_widget;
		true
	end
	else if key = _e then
	begin
		the_end := true;
		stop_timer ();
		GtkBase.Widget.queue_draw w#as_widget;
		true
	end
	else
		false

let redraw (dr: GDraw.drawable) l_timer l_turn ev =
	Pango.Layout.set_text l_timer (Printf.sprintf "%02d:%02d" !timer_mins !timer_secs);
	if !the_end then
	begin
		Pango.Layout.set_text l_turn "";
		Pango.Layout.set_text l_timer "THE END";
		stop_timer ()
	end
	else
	begin
		if Array.length !turns.(!current_turn).phases > 1 then
			Pango.Layout.set_text l_turn (Printf.sprintf "TURN %d%s, %s" (!current_turn + 1) (name_of_turn !current_turn) (name_of_phase !current_turn !current_phase))
		else
			Pango.Layout.set_text l_turn (Printf.sprintf "TURN %d%s" (!current_turn + 1) (name_of_turn !current_turn))
	end;
	let (x, y) = dr#size in
	let (w, h) = Pango.Layout.get_pixel_size l_timer in
	dr#put_layout ~x:((x - w) / 2) ~y:((y - h) / 2) (*~fore:`WHITE ~back:`BLACK*) l_timer;
	let (w, h) = Pango.Layout.get_pixel_size l_turn in
	dr#put_layout ~x:((x - w) / 2) ~y:5 (*~fore:`WHITE ~back:`BLACK*) l_turn;
	false

let () =
	Arg.parse arg_spec (fun s -> file_names := s::!file_names) "Usage: metags [parameters] [files]";
	List.iter (fun f ->
		read_from_file f 
	) !file_names;

	GtkMain.Main.init ();
	let w = GWindow.window ~show:true ~width:300 ~height:300 ~title:"MeTAGS" () in
	let a = GMisc.drawing_area ~packing:w#add () in
	let aw = a#misc#realize (); a#misc#window in
	let dr = new GDraw.drawable aw in

	let ctx = a#misc#create_pango_context in
	let l_timer = ctx#create_layout in
	let fd_timer = Pango.Font.copy ctx#font_description in
	Pango.Font.set_size fd_timer (256 * Pango.scale);
	Pango.Layout.set_font_description l_timer fd_timer;
	let l_turn = ctx#create_layout in
	let fd_turn = Pango.Font.copy ctx#font_description in
	Pango.Font.set_size fd_turn (32 * Pango.scale);
	Pango.Layout.set_font_description l_turn fd_turn;

	w#event#connect#key_press ~callback:(keypress w a dr);
	new_phase a dr;
	start_timer w a dr;

	a#event#connect#expose ~callback:(redraw dr l_timer l_turn);
	
	if !full_screen then
		w#fullscreen ();
	GMain.Main.main ()
