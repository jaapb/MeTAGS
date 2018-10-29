open GdkKeysyms

let phases = [| [| 10; 30; 10 |]; [| 5; 20; 5 |]; [| 5; 20; 5 |] |]
let phase_names = [| "Preparation"; "Combat"; "Team Time" |]

let current_turn = ref 0
let nr_turns = Array.length phases
let nr_phases = Array.length phases.(0)
let current_phase = ref 0
let timer_mins = ref phases.(0).(0)
let timer_secs = ref 0
let the_end = ref false

let timer = ref None

let advance_phase () =
	incr current_phase;
	if !current_phase >= nr_phases then
	begin
		incr current_turn;
		if !current_turn >= nr_turns then
		begin
			current_turn := 0;
			the_end := true
		end;
		current_phase := 0;
	end;
	timer_mins := phases.(!current_turn).(!current_phase);
	timer_secs := 0

let stop_timer () =
	match !timer with
	| None -> ()
	| Some t -> GMain.Timeout.remove t; timer := None

let start_timer w =
	timer := Some (GMain.Timeout.add ~ms:1000 ~callback:(fun () ->
		decr timer_secs;
		if !timer_secs <= 0 then
		begin
			if !timer_mins <= 0 then
				advance_phase ()
			else
			begin
				decr timer_mins;
				timer_secs := 59
			end
		end;
		GtkBase.Widget.queue_draw w#as_widget;
		true))

let reset_timer w =
	stop_timer ();
	start_timer w

let keypress w ev =
	let key = GdkEvent.Key.keyval ev in
	if key = _Escape then
	begin
		GtkMain.Main.quit ();
		exit 0
	end
	else if key = _Page_Down then
	begin
		advance_phase ();
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

let _ =
	GtkMain.Main.init ();
	let w = GWindow.window ~show:true ~width:300 ~height:300 ~title:"MeTAGS" () in
	w#event#connect#key_press ~callback:(keypress w);
	let a = GMisc.drawing_area ~packing:w#add () in
	a#misc#modify_bg [`NORMAL, `BLACK; `ACTIVE, `BLACK; `PRELIGHT, `BLACK; `INSENSITIVE, `BLACK; `SELECTED, `BLACK];

	let aw = a#misc#realize (); a#misc#window in
	let dr = new GDraw.drawable aw in
	dr#set_background `BLACK;
	dr#set_foreground `WHITE;

	let ctx = a#misc#create_pango_context in
	let l = ctx#create_layout in
	let fd = Pango.Font.copy ctx#font_description in
	Pango.Font.set_size fd (72 * Pango.scale);
	Pango.Layout.set_font_description l fd;
	let l2 = ctx#create_layout in
	let fd2 = Pango.Font.copy ctx#font_description in
	Pango.Font.set_size fd2 (20 * Pango.scale);
	Pango.Layout.set_font_description l2 fd2;

	start_timer w;

	a#event#connect#expose ~callback:(fun ev -> 
		Pango.Layout.set_text l (Printf.sprintf "%02d:%02d" !timer_mins !timer_secs);
		if !the_end then
		begin
			Pango.Layout.set_text l2 "";
			Pango.Layout.set_text l "THE END";
			stop_timer ()
		end
		else
		begin
			if nr_phases > 1 then
				Pango.Layout.set_text l2 (Printf.sprintf "TURN %d, %s" (!current_turn + 1) phase_names.(!current_phase))
			else
				Pango.Layout.set_text l2 (Printf.sprintf "TURN %d" (!current_turn + 1));
		end;
		let (x, y) = dr#size in
		let (w, h) = Pango.Layout.get_pixel_size l in
		dr#put_layout ~x:((x - w) / 2) ~y:((y - h) / 2) ~fore:`WHITE ~back:`BLACK l;
		let (w, h) = Pango.Layout.get_pixel_size l2 in
		dr#put_layout ~x:((x - w) / 2) ~y:5 ~fore:`WHITE ~back:`BLACK l2;
		false
	);
	
	w#fullscreen ();
	GMain.Main.main ()
