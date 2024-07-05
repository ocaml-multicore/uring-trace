module W = Eio.Buf_write

type strings = {
  mutable next : int;
  to_string : string option array;
  to_index : (string, int) Hashtbl.t;
}

type thread = { pid : int64; tid : int64 }

type threads = {
  mutable next : int;
  to_thread : thread option array;
  to_index : (thread, int) Hashtbl.t;
}

type t = { w : W.t; strings : strings; threads : threads }

let ( ||| ) = Int64.logor
let ( <<< ) = Int64.shift_left
let i64 = Int64.of_int
let word t x = W.LE.uint64 t.w x

let record ?(data = 0L) ~words ~ty t =
  word t (i64 ty ||| (i64 words <<< 4) ||| (data <<< 16))

let metadata ~ty ~data t = record t ~words:1 ~data:(data <<< 4 ||| i64 ty) ~ty:0
let traceinfo ~ty ~data t = metadata t ~ty:4 ~data:(data <<< 4 ||| i64 ty)
let magic_number t = traceinfo t ~ty:0 ~data:0x16547846L

module String_ref = struct
  type t = Ref of int | Inline of string

  let strlen s = (String.length s + 7) / 8

  let lookup t = function
    | "" -> Ref 0
    | s -> (
        match Hashtbl.find_opt t.strings.to_index s with
        | Some i -> Ref i
        | None ->
            if String.length s > 32000 then invalid_arg "String too long";
            Inline s)

  let encode = function Ref x -> x | Inline s -> 0x8000 lor String.length s
  let words = function Ref _ -> 0 | Inline s -> strlen s
  let pad_buffer = String.make 7 (Char.chr 0)

  let write_padded w s =
    W.string w s;
    let x = String.length s land 7 in
    if x > 0 then W.string w pad_buffer ~len:(8 - x)

  let write_inline t = function Ref _ -> () | Inline s -> write_padded t.w s

  let add t s =
    if not (Hashtbl.mem t.strings.to_index s) then (
      let i = t.strings.next in
      t.strings.next <- (if i = 0x7fff then 1 else i + 1);
      Option.iter (Hashtbl.remove t.strings.to_index) t.strings.to_string.(i);
      t.strings.to_string.(i) <- Some s;
      Hashtbl.add t.strings.to_index s i;
      let words = strlen s + 1 in
      let data = i64 i ||| (i64 (String.length s) <<< 16) in
      record t ~words ~data ~ty:2;
      write_padded t.w s)

  let create () =
    {
      next = 1;
      to_string = Array.make 0x8000 None;
      to_index = Hashtbl.create 200;
    }
end

module Thread_ref = struct
  let lookup t v =
    match Hashtbl.find_opt t.threads.to_index v with
    | Some i -> `Ref i
    | None -> `Inline v

  let encode = function `Ref x -> x | `Inline _ -> 0
  let size = function `Ref _ -> 0 | `Inline _ -> 2

  let write_inline t = function
    | `Ref _ -> ()
    | `Inline { pid; tid } ->
        word t pid;
        word t tid

  let add t v =
    if not (Hashtbl.mem t.threads.to_index v) then (
      let i = t.threads.next in
      t.threads.next <- (if i = 0xff then 1 else i + 1);
      Option.iter (Hashtbl.remove t.threads.to_index) t.threads.to_thread.(i);
      t.threads.to_thread.(i) <- Some v;
      Hashtbl.add t.threads.to_index v i;
      record t ~words:3 ~data:(i64 i) ~ty:3;
      word t v.pid;
      word t v.tid)

  let create () =
    {
      next = 1;
      to_thread = Array.make 0x100 None;
      to_index = Hashtbl.create 20;
    }
end

type arg =
  [ `Unit
  | `Int64 of int64
  | `Pointer of int64
  | `Koid of int64
  | `String of string ]

type args = (string * arg) list

module Arg = struct
  type t =
    | Unit
    | Int64 of int64
    | Pointer of int64
    | String of String_ref.t
    | Koid of int64

  let ty = function
    | Unit -> 0
    | Int64 _ -> 3
    | String _ -> 6
    | Pointer _ -> 7
    | Koid _ -> 8

  let add t : arg -> unit = function
    | `Unit | `Koid _ | `Pointer _ | `Int64 _ -> ()
    | `String s -> String_ref.add t s

  let lookup t : arg -> t = function
    | `Unit -> Unit
    | `Int64 x -> Int64 x
    | `Pointer x -> Pointer x
    | `Koid x -> Koid x
    | `String s -> String (String_ref.lookup t s)

  let header_value = function
    | Unit | Koid _ | Pointer _ | Int64 _ -> 0L
    | String s -> i64 (String_ref.encode s)

  let words = function
    | Unit -> 0
    | Int64 _ -> 1
    | Koid _ -> 1
    | Pointer _ -> 1
    | String s -> String_ref.words s

  let write_inline t = function
    | Unit -> ()
    | Koid x | Pointer x | Int64 x -> word t x
    | String s -> String_ref.write_inline t s
end

module Args = struct
  let add t =
    List.iter (fun (k, v) ->
        String_ref.add t k;
        Arg.add t v)

  let lookup t =
    List.map (fun (k, v) -> (String_ref.lookup t k, Arg.lookup t v))

  let words =
    List.fold_left
      (fun acc (k, v) -> acc + 1 + String_ref.words k + Arg.words v)
      0

  let write t =
    List.iter @@ fun (k, v) ->
    let words = 1 + String_ref.words k + Arg.words v in
    let value = Arg.header_value v in
    word t
      (i64 (Arg.ty v)
      ||| (i64 words <<< 4)
      ||| (i64 (String_ref.encode k) <<< 16)
      ||| (value <<< 32));
    String_ref.write_inline t k;
    Arg.write_inline t v
end

let event ~ty ?(args = []) ?correlation_id t ~name ~thread ~category ~ts =
  String_ref.add t category;
  String_ref.add t name;
  Thread_ref.add t thread;
  Args.add t args;
  let n_args = List.length args in
  let name = String_ref.lookup t name in
  let category = String_ref.lookup t category in
  let thread = Thread_ref.lookup t thread in
  let args = Args.lookup t args in
  let event_specific = match correlation_id with None -> 0 | Some _ -> 1 in
  let words =
    2 + Thread_ref.size thread + String_ref.words name
    + String_ref.words category + Args.words args + event_specific
  in
  record t ~ty:4 ~words
    ~data:
      (i64 ty
      ||| (i64 n_args <<< 4)
      ||| (i64 (Thread_ref.encode thread) <<< 8)
      ||| (i64 (String_ref.encode category) <<< 16)
      ||| (i64 (String_ref.encode name) <<< 32));
  word t ts;
  Thread_ref.write_inline t thread;
  String_ref.write_inline t category;
  String_ref.write_inline t name;
  Args.write t args;
  match correlation_id with None -> () | Some i64 -> word t i64

let instant_event = event ~ty:0 ?correlation_id:None
let duration_begin = event ~ty:2 ?correlation_id:None
let duration_end = event ~ty:3 ?correlation_id:None
let flow_begin ?args t ~correlation_id = event ?args t ~ty:8 ~correlation_id
let flow_step ?args t ~correlation_id = event ?args t ~ty:9 ~correlation_id
let flow_end ?args t ~correlation_id = event ?args t ~ty:10 ~correlation_id

let scheduling ~words ~ty ~data t =
  record t ~ty:8 ~words ~data:(data ||| (i64 ty <<< 44))

let user_object ?(args = []) t ~name ~thread id =
  Args.add t args;
  String_ref.add t name;
  Thread_ref.add t thread;
  let argc = List.length args in
  let args = Args.lookup t args in
  let name = String_ref.lookup t name in
  let thread = Thread_ref.lookup t thread in
  let words =
    2 + String_ref.words name + Thread_ref.size thread + Args.words args
  in
  record t ~ty:6 ~words
    ~data:
      (i64 (Thread_ref.encode thread)
      ||| (i64 (String_ref.encode name) <<< 8)
      ||| (i64 argc <<< 24));
  word t id;
  Thread_ref.write_inline t thread;
  String_ref.write_inline t name;
  Args.write t args

let kernel_object ?(args = []) t ~name ty id =
  Args.add t args;
  String_ref.add t name;
  let argc = List.length args in
  let args = Args.lookup t args in
  let name = String_ref.lookup t name in
  let words = 2 + String_ref.words name + Args.words args in
  let ty = match ty with `Thread -> 2 in
  record t ~ty:7 ~words
    ~data:(i64 ty ||| (i64 (String_ref.encode name) <<< 8) ||| (i64 argc <<< 24));
  word t id;
  Args.write t args

let thread_wakeup ?(args = []) t ~cpu ~ts id =
  Args.add t args;
  let args = Args.lookup t args in
  let words = 3 + Args.words args in
  let argc = List.length args in
  scheduling ~words ~ty:2 ~data:(i64 argc ||| (i64 cpu <<< 4)) t;
  word t ts;
  word t id;
  Args.write t args

let of_writer w =
  let t =
    { w; strings = String_ref.create (); threads = Thread_ref.create () }
  in
  magic_number t;
  t
