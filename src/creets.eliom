
[%%client

open Js_of_ocaml
open Js_of_ocaml_lwt
open Config

type point_i = {mutable x: int; mutable y: int}
type point_f = {mutable x: float; mutable y: float}
type rectangle = {mutable left: int; mutable top: int; mutable right: int; mutable bottom: int}
type creet_state = Healthy | Sick | Mean | Berserk | Dead

class creet = object (self)
	val dom_elt : Dom_html.divElement Js.t = Dom_html.createDiv Dom_html.document; (* The DOM element representing the creet *)
	val container : Dom_html.element Js.t = Dom_html.getElementById "game_container";
	val hospital : Dom_html.element Js.t = Dom_html.getElementById "hospital";
	val river : Dom_html.element Js.t = Dom_html.getElementById "river";
	val mutable container_bbox : rectangle = { left = 0; top = 0; right = 0; bottom = 0 };
	val mutable hospital_bbox : rectangle = { left = 0; top = 0; right = 0; bottom = 0 };
	val mutable river_bbox : rectangle = { left = 0; top = 0; right = 0; bottom = 0 };
	val mutable creet_bbox : rectangle = { left = 0; top = 0; right = 0; bottom = 0 };

	val pos : point_i = { x = 0; y = 0};
	val direction : point_f = { x = 0.; y = 0.};
	val mutable picked : bool = false;
	val mutable colliding : bool = false;
	val mutable state : creet_state = Healthy
	val mutable speed : float = Config.initial_creet_speed
	val mutable size : float = Config.initial_creet_size
	val mutable anim_step : int = 0
	val mutable tick_alive : int = 0

	(* Setters *)
	method private set_bbox (dom_elt_rect : Dom_html.clientRect Js.t) (bbox_to_set : rectangle) = 
		bbox_to_set.top <- int_of_float dom_elt_rect##.top;
		bbox_to_set.bottom <- int_of_float dom_elt_rect##.bottom;
		bbox_to_set.left <- int_of_float dom_elt_rect##.left;
		bbox_to_set.right <- int_of_float dom_elt_rect##.right;

	method set_position new_x new_y =
		creet_bbox.left <- new_x;
		creet_bbox.right <- new_x + int_of_float size;
		creet_bbox.top <- new_y;
		creet_bbox.bottom <- new_y + int_of_float size;
		dom_elt##.style##.left := Js.string (Printf.sprintf "%dpx" new_x);
		dom_elt##.style##.top := Js.string (Printf.sprintf "%dpx" new_y);
		
	method private set_size (new_size : float) =
		size <- new_size;
		dom_elt##.style##.transform := Js.string (Printf.sprintf "scale(%f)" (size /. 32.));

	method private heal () =
		state <- Healthy;
		anim_step <- 0;
		dom_elt##.style##.backgroundImage := Js.string "url('/css/assets/Healthy.png')";
		self#set_size Config.initial_creet_size;
		self#random_direction ();
		speed <- Config.initial_creet_speed;

	method private make_sick () =
		state <- Sick;
		speed <- 0.85;
		anim_step <- 0;
		dom_elt##.style##.backgroundImage := Js.string "url('/css/assets/Sick.png')";

	method private make_mean () =
		state <- Mean;
		speed <- 0.85;
		anim_step <- 0;
		dom_elt##.style##.backgroundImage := Js.string "url('/css/assets/Mean.png')";
		ignore(dom_elt##.style##setProperty (Js.string "transition") (Js.string "transform 5s linear") Js.undefined);
		self#set_size (Config.mean_size);

	method private make_berserk () =
		state <- Berserk;
		speed <- 0.85;
		anim_step <- 0;
		dom_elt##.style##.backgroundImage := Js.string "url('/css/assets/Berserk.png')";
		dom_elt##.style##.transform := Js.string (Printf.sprintf "scale(%f)" (size /. 64.));
		ignore(dom_elt##.style##setProperty (Js.string "transition") (Js.string "transform 10s linear") Js.undefined);
		self#set_size (Config.initial_creet_size *. 1.1);

	method remove () =
		if state = Mean then dom_elt##.style##.backgroundImage := Js.string "url('/css/assets/Mean_Death.png')";
		if state = Berserk then dom_elt##.style##.backgroundImage := Js.string "url('/css/assets/Berserk_Death.png')";
		anim_step <- 0;
		Lwt.async (fun () -> self#death_animation ());
		state <- Dead;
	

	(* Getters *)
	method get_bbox = creet_bbox

	method get_state = state

	method is_picked = picked

	method private random_direction () =
		let angle = (Random.float (2. *. 3.14159)) in
		direction.x <- cos angle;
		direction.y <- sin angle;

	method private distance (other : creet) =
	let dx = float_of_int(other#get_bbox.left - creet_bbox.left) in
	let dy = float_of_int(other#get_bbox.top - creet_bbox.top) in
	sqrt (dx *. dx +. dy *. dy)

	method private dir_to_closest (creets : creet list) =
		match creets with
		| [] -> self#random_direction ()
		| head :: tail ->
			let closest = List.fold_left (fun closest c ->
				if self#distance c < self#distance closest then c
				else closest ) head tail in
			let other_bbox = closest#get_bbox in
			let dir = {x = float_of_int (other_bbox.left - creet_bbox.left); y = float_of_int(other_bbox.top - creet_bbox.top)} in
			direction.x <- dir.x;
			direction.y <- dir.y
	
	method private check_border_collision = 
		match creet_bbox.left <= container_bbox.left,
			creet_bbox.right >= container_bbox.right,
			creet_bbox.top <= container_bbox.top,
			creet_bbox.bottom >= container_bbox.bottom with
		| true, _, _, _	->
		self#set_position container_bbox.left creet_bbox.top;
		direction.x <- -. direction.x
		| _, true, _, _	->
		self#set_position (container_bbox.right - int_of_float size) creet_bbox.top;
		direction.x <- -. direction.x
		| _, _, true, _	->
		self#set_position creet_bbox.left container_bbox.top;
		direction.y <- -. direction.y
		| _, _, _, true	->
		self#set_position creet_bbox.left (container_bbox.bottom - int_of_float size);
		direction.y <- -. direction.y
		| _ , _ , _ , _	-> ();
	
	method private tick_creet_check () =
		let lift f = f (); Lwt.return_unit in
		let%lwt () = Lwt_js.sleep 10.0 in
		let%lwt () = 
		match state with
		| Sick ->
				let rnd = Random.int 100 in
				if rnd < 10 then lift self#make_berserk
				else if rnd < 20 then lift self#make_mean
				else Lwt.return_unit
			| Berserk -> 
				if size < Config.berserk_size then lift (fun () -> self#set_size(size *. 1.1))
				else lift self#remove
			| Mean ->
				if tick_alive = 10 then self#remove ();
				tick_alive <- tick_alive + 1;
				Lwt.return_unit;
			| _ -> Lwt.return_unit;
		in
		if state = Dead then Lwt.return_unit
		else self#tick_creet_check ()

	method private collide rect = 
		not (creet_bbox.right < rect.left ||
				 creet_bbox.left > rect.right ||
				 creet_bbox.bottom < rect.top ||
				 creet_bbox.top > rect.bottom)

	method private death_animation () =
		let%lwt () = Lwt_js.sleep 0.1 in
		dom_elt##.style##.backgroundPosition := Js.string(string_of_int (47 + (anim_step * 64)) ^ "px 240px");
		anim_step <- (anim_step + 1) mod 10;
		if anim_step <> 9 then self#death_animation ()
		else begin 
			Dom.removeChild container dom_elt;
			Lwt.return ()
		end

	method private update_sprite_loop () =
		let%lwt () = Lwt_js.sleep 0.1 in
		dom_elt##.style##.backgroundPosition := Js.string(string_of_int (47 + (anim_step * 64)) ^ "px 240px");
		if state = Sick then anim_step <- (anim_step + 1) mod 5
		else anim_step <- (anim_step + 1) mod 8;
		if state <> Dead then self#update_sprite_loop ()
		else Lwt.return ()

	method private normalize v = 
		let mag = sqrt (v.x *. v.x +. v.y *. v.y) in
		if mag = 0.0 then {x = 0.0; y = 0.0}
		else {x = v.x /. mag; y = v.y /. mag}

	method move (global_speed : float) (creets : creet list) =
		if picked = false then begin
			let healthy, sick = List.partition (fun c -> c#get_state = Healthy) creets in

			(* Direction Changes *)
			if state = Mean then
				self#dir_to_closest healthy
			else begin
				let rnd = Random.int 500 in
				if rnd = 1 then self#random_direction ()
			end;

			(* Collision checks*)
			self#check_border_collision;

			(* Position Update *)
			let norm_dir = self#normalize direction in
			let dx = int_of_float(norm_dir.x *. (speed +. global_speed)) in
			let dy = int_of_float(norm_dir.y *. (speed +. global_speed)) in
			self#set_position (creet_bbox.left + dx) (creet_bbox.top + dy);

			(* Sick Updates *)
			if state = Healthy then begin
				if self#collide river_bbox then self#make_sick ();
				List.iter(fun c -> 
					if self#collide c#get_bbox && c#is_picked = false then begin
						let rnd = Random.int 100 in
						if rnd <= 2 then self#make_sick ()
					end
				) sick;
			end
		end

	method private handle_events () = 
		let open Lwt_js_events in
		Lwt.async (fun () ->
			mousedowns dom_elt (fun ev _ ->
				if not (state = Healthy || state = Sick) then Lwt.return_unit
				else begin
					picked <- true;
					let mouse_x = ev##.clientX in
					let mouse_y = ev##.clientY in
					let offset_x = mouse_x - creet_bbox.left in
					let offset_y = mouse_y - creet_bbox.top in
					Lwt.pick [
						(mousemoves Dom_html.document (fun ev _ ->
							let mouse_x = ev##.clientX in
							let mouse_y = ev##.clientY in
							self#set_position (mouse_x - offset_x) (mouse_y - offset_y);
							Lwt.return ()
						));
						let%lwt _ = mouseup Dom_html.document in
						if self#collide hospital_bbox && state <> Healthy then
							self#heal ();
						picked <- false;
						Lwt.return ()
					]
				end
			)
		)

	method init () =
		(* Creet Init *)
		dom_elt##.className := Js.string "creet";
		dom_elt##.style##.backgroundImage := Js.string "url('/css/assets/Healthy.png')";
		self#set_size Config.initial_creet_size;
		Dom.appendChild container dom_elt;
		self#set_position (container##.offsetWidth / 2) (container##.offsetHeight / 2);
		self#random_direction ();
		
		(* Bboxes Init *)
		self#set_bbox dom_elt##getBoundingClientRect creet_bbox;
		self#set_bbox container##getBoundingClientRect container_bbox;
		self#set_bbox river##getBoundingClientRect river_bbox;
		self#set_bbox hospital##getBoundingClientRect hospital_bbox;
		
		self#handle_events ();
		Lwt.async (fun () -> self#update_sprite_loop ());
		Lwt.async (fun () -> self#tick_creet_check ());
end

]