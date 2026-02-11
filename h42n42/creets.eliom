
[%%client

open Js_of_ocaml
open Js_of_ocaml_lwt
open Config

type point_i = {mutable x: int; mutable y: int}
type point_f = {mutable x: float; mutable y: float}
type rectangle = {mutable left: int; mutable top: int; mutable right: int; mutable bottom: int}
type creet_state = Healthy | Sick | Mean | Berserk

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
    (* dom_elt##.style##.backgroundColor := Js.string "green"; *)
    anim_step <- 0;
    dom_elt##.style##.backgroundImage := Js.string "url('/css/assets/Healthy.png')";
    self#set_size Config.initial_creet_size;
    self#random_direction ();
    speed <- Config.initial_creet_speed;

  method private make_sick () =
    let rnd = Random.int 100 in
    if rnd <= 10 then self#make_berserk ()
    else begin
      state <- Sick;
      speed <- 0.85;
      anim_step <- 0;
      dom_elt##.style##.backgroundImage := Js.string "url('/css/assets/Sick.png')";
      (* dom_elt##.style##.backgroundColor := Js.string "yellow" *)
    end

  method private make_mean () =
    state <- Mean;
    speed <- 0.85;
    anim_step <- 0;
    (* dom_elt##.style##.backgroundColor := Js.string "orange" *)
    dom_elt##.style##.backgroundImage := Js.string "url('/css/assets/Mean.png')";

  method private make_berserk () =
    state <- Berserk;
    speed <- 0.85;
    anim_step <- 0;
    dom_elt##.style##.backgroundImage := Js.string "url('/css/assets/Berserk.png')";
    (* dom_elt##.style##.backgroundColor := Js.string "red" *)


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
      let dist = sqrt (dir.x *. dir.x +. dir.y *. dir.y) in
      direction.x <- dir.x /. dist;
      direction.y <- dir.y /. dist
  
	method private check_border_collision = 
		match creet_bbox.left <= container_bbox.left,
			creet_bbox.right >= container_bbox.right,
			creet_bbox.top <= container_bbox.top,
			creet_bbox.bottom >= container_bbox.bottom with
		| true, _, _, _  ->
    self#set_position container_bbox.left creet_bbox.top;
		direction.x <- -. direction.x
		| _, true, _, _  ->
    self#set_position (container_bbox.right - int_of_float size) creet_bbox.top;
		direction.x <- -. direction.x
		| _, _, true, _  ->
    self#set_position creet_bbox.left container_bbox.top;
		direction.y <- -. direction.y
		| _, _, _, true  ->
    self#set_position creet_bbox.left (container_bbox.bottom - int_of_float size);
		direction.y <- -. direction.y
		| _ , _ , _ , _  -> ();

  method private check_river_collision = 
    if creet_bbox.top <= river_bbox.bottom then begin
      self#set_position creet_bbox.left river_bbox.bottom;
      direction.y <- -. direction.y;
      if state = Healthy then
        self#make_sick ();
    end
  
  method private collide rect = 
    not (creet_bbox.right < rect.left ||
         creet_bbox.left > rect.right ||
         creet_bbox.bottom < rect.top ||
         creet_bbox.top > rect.bottom)

  method private update_sprite_loop () =
    let%lwt () = Lwt_js.sleep 0.1 in
    dom_elt##.style##.backgroundPosition := Js.string(string_of_int (47 + (anim_step * 64)) ^ "px 240px");
    if state = Sick then 
      anim_step <- (anim_step + 1) mod 5
    else 
      anim_step <- (anim_step + 1) mod 8;
    self#update_sprite_loop ()


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
      self#check_river_collision;

      (* Position Update *)
      let dx = int_of_float(direction.x *. (speed +. global_speed)) in
      let dy = int_of_float(direction.y *. (speed +. global_speed)) in
      self#set_position (creet_bbox.left + dx) (creet_bbox.top + dy);

      (* State Updates *)
      match state with
      | Healthy -> 
          if self#collide river_bbox then
            self#make_sick ();
          List.iter(fun c -> 
            match self#collide c#get_bbox, colliding, c#is_picked with
            | true, false, false ->
              colliding <- true;
              let rnd = Random.int 100 in
              if rnd <= 2 then 
                let rnd = Random.int 100 in
                if rnd <= 10 then self#make_mean ()
                else self#make_sick ()
            | false, true, _ ->
              colliding <- false
            | _ -> ()
          ) sick;
      | Mean ->
        if size > Config.mean_size then
          self#set_size (size -. 0.01);
      | Berserk ->
        if size < Config.berserk_size then
          self#set_size (size +. 0.1);
      | _ -> ();
    end

	method private handle_events () = 
		let open Lwt_js_events in
		Lwt.async (fun () ->
			mousedowns dom_elt (fun ev _ ->
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
			)
		)

  method init () =
    (* Creet Init *)
		dom_elt##.className := Js.string "creet";
    (* dom_elt##.style##.backgroundColor := Js.string "green"; *)
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

  method remove () =
    Dom.removeChild container dom_elt
end

]