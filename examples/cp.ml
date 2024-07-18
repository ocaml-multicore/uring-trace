let ( / ) = Eio.Path.( / )

let () =
  let polling_timeout =
    try Option.some (int_of_string Sys.argv.(4)) with _ -> None
  in
  Eio_linux.run ?polling_timeout ~block_size:8192 @@ fun env ->
  let cwd = Eio.Stdenv.cwd env in
  let src = cwd / Sys.argv.(1) in
  let dst = cwd / Sys.argv.(2) in
  let algo = try Sys.argv.(3) with _ -> "kw" in
  match algo with
  | "kw" -> Cp_imp.copy_dfs_2 ~max_descriptors:4 ~src ~dst ()
  | "kentookura" -> Cp_imp.copy_kentookura ~src ~dst ()
  | "kentookura_seq" -> Cp_imp.copy_kentookura_seq ~src ~dst ()
  | _ -> failwith "algo is one of <kw/kentookura>"
