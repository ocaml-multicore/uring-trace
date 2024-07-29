(** Write files in Fuchsia trace format: https://fuchsia.dev/fuchsia-src/reference/tracing/trace-format *)

type t

type arg =
  [ `Unit
  | `Int64 of int64
  | `Pointer of int64
  | `Koid of int64
  | `String of string ]

type args = (string * arg) list
type thread = { pid : int64; tid : int64 }

val of_writer : Eio.Buf_write.t -> t

val instant_event :
  ?args:args ->
  t ->
  name:string ->
  thread:thread ->
  category:string ->
  ts:int64 ->
  unit

val duration_begin :
  ?args:args ->
  t ->
  name:string ->
  thread:thread ->
  category:string ->
  ts:int64 ->
  unit

val duration_end :
  ?args:args ->
  t ->
  name:string ->
  thread:thread ->
  category:string ->
  ts:int64 ->
  unit

val flow_begin :
  ?args:args ->
  t ->
  correlation_id:int64 ->
  name:string ->
  thread:thread ->
  category:string ->
  ts:int64 ->
  unit

val flow_step :
  ?args:args ->
  t ->
  correlation_id:int64 ->
  name:string ->
  thread:thread ->
  category:string ->
  ts:int64 ->
  unit

val flow_end :
  ?args:args ->
  t ->
  correlation_id:int64 ->
  name:string ->
  thread:thread ->
  category:string ->
  ts:int64 ->
  unit

val user_object :
  ?args:args -> t -> name:string -> thread:thread -> int64 -> unit

val kernel_object :
  ?args:args -> t -> name:string -> [ `Thread ] -> int64 -> unit

val thread_wakeup : ?args:args -> t -> cpu:int -> ts:int64 -> int64 -> unit
