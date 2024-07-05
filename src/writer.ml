module FW = Fxt.Write

let category = "uring"

module RingCtxPtr = struct
  open Ctypes

  type t = unit ptr

  let compare = ptr_compare
  let show t = string_of (ptr void) t
end

module Track = struct
  type t = FW.thread

  let compare (t1 : t) (t2 : t) =
    let ( + ) = Int64.add in
    Int64.compare (t1.pid + t1.tid) (t2.pid + t2.tid)
end

module RingCtxSet = Set.Make (RingCtxPtr)
module TrackSet = Set.Make (Track)

type t = {
  mutable rings : RingCtxSet.t;
  mutable tracks : TrackSet.t;
  fxt : FW.t;
}

let make fxt = { rings = RingCtxSet.empty; tracks = TrackSet.empty; fxt }
let of_writer = FW.of_writer

let create_ring_ev ?args t ~ring_ctx ~pid ~tid ~name ~comm ~ts =
  (* Register new ring for tracking *)
  Printf.printf "Registering ring at %s\n%!" (RingCtxPtr.show ring_ctx);
  t.rings <- RingCtxSet.add ring_ctx t.rings;
  let thread = FW.{ pid; tid } in
  t.tracks <- TrackSet.add thread t.tracks;
  (* Register track name for this thread, subsequent events with the
     same FW.thread entry will get added here *)
  FW.kernel_object t.fxt ~args:[ ("process", `Koid pid) ] ~name:comm `Thread tid;
  FW.instant_event ?args t.fxt ~name ~thread ~category ~ts

(* kprobe:io_init_new_worker *)
let create_worker_ev ?args t ~pid ~tid ~worker_tid ~name ~comm ~ts =
  let track_name = Printf.sprintf "%s:io-worker" comm in
  Printf.printf "Spawning %s:%Ld:%d\n%!" track_name pid worker_tid;

  let thread = FW.{ pid; tid = Int64.of_int worker_tid } in
  t.tracks <- TrackSet.add thread t.tracks;
  (* Register track name for this io-worker thread, subsequent events
     with the same FW.thread entry will get added here *)
  FW.kernel_object t.fxt
    ~args:[ ("process", `Koid pid) ]
    ~name:track_name `Thread thread.tid;
  (* This spawn event should be displayed under the actual thread that
     called it *)
  FW.instant_event ?args t.fxt ~name ~thread:(FW.{pid; tid}) ~category ~ts

(* Flow events are usually applied to span events. However our use for
   flows here are to connect tracepoints. To get flow events to mimic
   instant events, we write the duration_begin -> flow_ev ->
   duration_end with all timestamps begin equal. This dance is
   neccessary to get perfetto to display things nicely*)
let flow_instance_aux ?args t ~ring_ctx ~name ~pid ~tid ~ts ~correlation_id
    ~(flow_ev : [ `Start | `Step | `End ]) =
  if RingCtxSet.mem ring_ctx t.rings then (
    let thread = FW.{ pid; tid } in
    FW.duration_begin t.fxt ~name ~thread ~category ~ts ?args;
    (match flow_ev with
    | `Start ->
        FW.flow_begin ?args t.fxt ~name ~thread ~category ~ts ~correlation_id
    | `Step ->
        FW.flow_step ?args t.fxt ~name ~thread ~category ~ts ~correlation_id
    | `End ->
        FW.flow_end ?args t.fxt ~name ~thread ~category ~ts ~correlation_id);
    FW.duration_end t.fxt ~name ~thread ~category ~ts ?args)
  else Printf.eprintf "No registered ring found for submission event\n%!\n"

let submit_ev = flow_instance_aux ~flow_ev:`Start
let flow_ev = flow_instance_aux ~flow_ev:`Step
let complete_ev = flow_instance_aux ~flow_ev:`End

let instant_event ?args t ~pid ~tid =
  let thread = FW.{ pid; tid } in
  FW.instant_event ?args t.fxt ~category ~thread

let syscall_begin ?args t ~pid ~tid =
  FW.duration_begin ?args t.fxt ~thread:FW.{ pid; tid } ~category:"syscalls"

let syscall_end ?args t ~pid ~tid =
  FW.duration_end ?args t.fxt ~thread:FW.{ pid; tid } ~category:"syscalls"
