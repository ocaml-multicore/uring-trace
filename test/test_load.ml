open Libbpf

let () =
  let obj_path = Site.bpf_object_path in
  let program_names = Site.bpf_program_names in
  with_bpf_object_open_load_link ~obj_path ~program_names (fun _ _ ->
      Printf.printf "Load success\n%!")
