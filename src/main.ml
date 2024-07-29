open Cmdliner

let run tracefile sampling busywait =
  let open Driver in
  (* Check running root *)
  if Unix.geteuid () <> 0 then failwith "Please run as root";
  let poll_behaviour = if busywait then Busywait else Poll 100 in
  run ~tracefile ~sampling ~poll_behaviour

(* Output *)
let tracefile =
  let doc = "Where the output trace should go" in
  Arg.(value & opt string "trace.fxt" (info [ "o; output" ] ~doc))

(* Sampling *)
let sampling =
  let doc = "Turn on sampling on high workloads to reduce dropping events" in
  Arg.(value & flag (info [ "s; sampling" ] ~doc))

(* Polling *)
let polling =
  let doc = "Turn on busywaiting on high workloads to reduce dropping events" in
  Arg.(value & flag (info [ "b; busywait" ] ~doc))

let cmd =
  let doc = "Visualize uring events" in
  let desc_blk =
    [
      `S "DESCRIPTION";
      `P
        "Low-impact tracing of io-uring. This tool generates a fuchsia trace \
         file that is meant to be displayed on Perfetto. It works by attaching \
         onto io-uring tracepoints using eBPF technology. As a result, it \
         requires root priviledges to run.";
    ]
  in
  let usage_blk =
    [
      `S "USAGE";
      `P
        "To use this tool against a program, open a separate terminal and run \
         $(b, sudo uring-trace) which will start the tracing process, now \
         execute your program and the tool will pickup on newly setup rings. \
         You can stop tracing at any time by hitting Ctrl-C";
    ]
  in
  let man : Manpage.block list = [ `Blocks desc_blk; `Blocks usage_blk ] in
  let info = Cmd.info "uring-trace" ~doc ~man in
  Cmd.v info Term.(const run $ tracefile $ sampling $ polling)

let () = exit (Cmd.eval cmd)
