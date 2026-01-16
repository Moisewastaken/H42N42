let%server application_name = "h42n42"
let%client application_name = Eliom_client.get_application_name ()


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
			h1 [txt "Welcome in my super site wouaib!"];
			div ~a:[a_id "container"] []
		]
	))
)
					

[%%client
open Js_of_ocaml
open Js_of_ocaml_lwt
open Creets

let () = Random.self_init ()

let rec controller creets =
	let global_speed = 1.5 in
	let%lwt () = Lwt_js.sleep 0.0001 in
	List.iter (fun c -> 
		Lwt.async (fun () ->
			c#move global_speed;
			Lwt.return ()
		)
	) creets;
	global_speed *. 2. |> ignore;
	controller creets

let () =
	Dom_html.window##.onload :=
	Dom_html.handler (fun _ ->
		let container = Dom_html.getElementById "container" in
		let creets = 
			let rec aux n acc =
				if n <= 0 then acc
				else aux (n - 1) ((new creet)::acc);
			in
			aux 20 [] in
		List.iter (fun c -> c#init container) creets;
		Lwt.async (fun () -> controller creets);
		Js._true
	)
]