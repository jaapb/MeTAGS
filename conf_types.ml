type colour_spec = [ `BLACK | `NAME of string | `RGB of int * int * int | `WHITE ]

type phase =
	{ name: string option;
		duration: int;
		background_colour: colour_spec;
		foreground_colour: colour_spec
	}	

type turn = 
	{ name: string option;
		duration: int;
		phases: phase array
	}	

type configuration = turn array
	
