let%server application_name = "h42n42"
let%client application_name = Eliom_client.get_application_name ()

let%server () =
    Ocsipersist_settings.set_db_file "local/var/data/h42n42/h42n42_db";

module%shared App = Eliom_registration.App (struct
    let application_name = application_name
    let global_data_path = Some ["__global_data__"]
  end)

let%client _ = Eliom_client.persist_document_head ()

let%server main_service =
  Eliom_service.create ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Get Eliom_parameter.unit) ()

let%client main_service = ~%main_service

let%shared () =
App.register ~service:main_service (fun () () ->
	Lwt.return
	Eliom_content.Html.F.(html
	(head
		(title (txt "h42n42"))
		[ css_link ~uri: (make_uri ~service:(Eliom_service.static_dir ()) ["css"; "h42n42.css"]) () ]
	)
	(body 
		[
      div ~a:[a_id "play_game_container"] [
        h1 [txt "H42N42"];
        button ~a:[a_id "play_button"] [txt "Play"];        
      ];
      div ~a:[a_id "game_over_container"] [
        h1 [txt "You lost !"];
        button ~a:[a_id "play_again_button"] [txt "Play Again"];        
      ];
			div ~a:[a_id "game_container"] [
        div ~a:[a_id "river"] [];
        div ~a:[a_id "hospital"] [];
      ];
		]
	))
)

[%%client

open Js_of_ocaml
open Js_of_ocaml_lwt
open Creets
open Config

let () = Random.self_init ()


let rec controller creets global_speed count =
  let%lwt () = Lwt_js.sleep 0.01 in
  List.iter (fun c -> 
    Lwt.async (fun () -> (
      c#move global_speed !creets;
      Lwt.return ()
    ))
  ) !creets;
  if not (List.exists (fun c -> c#get_state = Healthy) !creets) then begin
    List.iter (fun c -> c#remove ()) !creets;
    let game_over = Dom_html.getElementById "game_over_container" in
    game_over##.style##.display := Js.string "flex";
    Lwt.return ()
  end
  else begin
    let new_global_speed = if global_speed < Config.max_global_speed then global_speed +. 0.001 else global_speed in

    count := !count + 1;
    
    if !count = Config.creet_reproduce_count then begin
      let healthy, _ = List.partition (fun c -> c#get_state = Healthy) !creets in
      let new_creet = new creet in
      new_creet#init ();
      let random_creet = List.nth healthy (Random.int (List.length healthy)) in
      new_creet#set_position random_creet#get_bbox.left random_creet#get_bbox.top;
      creets := new_creet :: !creets;
      count := 0
    end;

    controller creets new_global_speed count
  end
  
let launch = Dom_html.handler (fun _ ->
  let play_game = Dom_html.getElementById "play_game_container" in
  play_game##.style##.display := Js.string "none";
  let game_over = Dom_html.getElementById "game_over_container" in
  game_over##.style##.display := Js.string "none";
  let creets = ref (
    let rec aux n acc =
      if n <= 0 then acc
      else aux (n - 1) ((new creet)::acc)
    in
    aux Config.initial_creet_count [])
  in
  List.iter (fun c -> c#init ()) !creets;
  Lwt.async (fun () -> controller creets Config.initial_global_speed (ref 0));
  Js._true
)

let () = 
  Dom_html.window##.onload := Dom_html.handler (fun _ ->
    let play_button = Dom_html.getElementById "play_button" in
    play_button##.onclick := launch;
    let play_again_button = Dom_html.getElementById "play_again_button" in
    play_again_button##.onclick := launch;
    Js._true
)

]
