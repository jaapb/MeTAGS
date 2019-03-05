type colour_spec = [`BLACK | `COLOR of Gdk.color | `NAME of string | `RGB of int * int * int | `WHITE ]

type phase =
	{ name: string option;
		duration: int;
		background_colour: colour_spec;
		foreground_colour: colour_spec;
		image: string option
	}	

type turn = 
	{ name: string option;
		phases: phase array
	}	

type configuration =
	{ turns: turn array;
		images: string list
	}
