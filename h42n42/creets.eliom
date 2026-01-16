[%%client

open Js_of_ocaml
open Js_of_ocaml_lwt

type point_i = {mutable x: int; mutable y: int}
type point_f = {mutable x: float; mutable y: float}
type rectangle = {mutable left: int; mutable top: int; mutable right: int; mutable bottom: int}

class creet = object (self)
	val dom_elt : Dom_html.divElement Js.t = Dom_html.createDiv Dom_html.document;
	val mutable bbox : rectangle = { left = 0; top = 0; right = 0; bottom = 0 };
	val pos : point_i = { x = 0; y = 0};
	val direction : point_f = { x = 0.; y = 0.};

	method private set_bbox (box : Dom_html.clientRect Js.t) = 
		bbox.top <- int_of_float box##.top;
		bbox.bottom <- int_of_float box##.bottom;
		bbox.left <- int_of_float box##.left;
		bbox.right <- int_of_float box##.right;

	method set_position new_x new_y =
		pos.x <- new_x;
		pos.y <- new_y;
		dom_elt##.style##.left := Js.string (Printf.sprintf "%dpx" pos.x);
		dom_elt##.style##.top := Js.string (Printf.sprintf "%dpx" pos.y);
		(* Js_of_ocaml.Firebug.console##log pos; *)

	method init (box : Dom_html.element Js.t) =
		dom_elt##.className := Js.string "creet";
		Dom.appendChild Dom_html.document##.body dom_elt;
		self#set_bbox box##getBoundingClientRect;
		self#set_position (Dom_html.window##.innerWidth / 2) (Dom_html.window##.innerHeight / 2);
		self#random_direction ();
		self#handle_events ();

	method private random_direction () =
		let angle = (Random.float (2. *. 3.14159)) in
		direction.x <- cos angle;
		direction.y <- sin angle;

	method private check_collision rect =
		if pos.x < rect.left || pos.x + 20 > rect.right then
			direction.x <- -. direction.x;
		if pos.y < rect.top || pos.y + 20 > rect.bottom then
			direction.y <- -. direction.y
		
	method move global_speed =
		let rnd = Random.int 100 in
		if rnd = 1 then self#random_direction ();
		self#check_collision bbox;
		let dx = int_of_float (direction.x *. global_speed) in
		let dy = int_of_float (direction.y *. global_speed) in
		self#set_position (pos.x + dx) (pos.y + dy);

	method private handle_events () = 
		let open Lwt_js_events in
		Lwt.async (fun () ->
			mousedowns dom_elt (fun ev _ ->
				let mouse_x = ev##.clientX in
				let mouse_y = ev##.clientY in
				let offset_x = mouse_x - pos.x in
				let offset_y = mouse_y - pos.y in
				Lwt.pick [
					(mousemoves Dom_html.document (fun ev _ ->
						let mouse_x = ev##.clientX in
						let mouse_y = ev##.clientY in
						self#set_position (mouse_x - offset_x) (mouse_y - offset_y);
						Lwt.return ()
					));
					(let%lwt _ = mouseup Dom_html.document in Lwt.return ())
				]
			)
		)
end
	
]