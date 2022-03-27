#[
  This file aims to load a null sink module without using shellExec or such.
  It uses the PulseAudio's asynchronous C API.

  https://gitlab.freedesktop.org/pulseaudio/pulseaudio/-/blob/master/src/utils/pactl.c
]#

import std / strformat

{.passL: "-lpulse".}
{.pragma: pulse, importc: "$1".}

const PA_INVALID_INDEX = uint32.high - 1 ## pulse/def.h

type
  pa_mainloop = object
  pa_io_event = object
  pa_time_event = object
  timeval = object
  pa_defer_event = object
  pa_context = object
  pa_operation = object
  pa_proplist = object

  pa_io_event_flags_t* = enum
    PA_IO_EVENT_NULL = 0, PA_IO_EVENT_INPUT = 1, PA_IO_EVENT_OUTPUT = 2,
    PA_IO_EVENT_HANGUP = 4, PA_IO_EVENT_ERROR = 8
  pa_io_event_cb_t* = proc (ea: ptr pa_mainloop_api; e: ptr pa_io_event; fd: cint;
                         events: pa_io_event_flags_t; userdata: pointer)
  pa_io_event_destroy_cb_t* = proc (a: ptr pa_mainloop_api; e: ptr pa_io_event;
                                 userdata: pointer)
  pa_time_event_cb_t* = proc (a: ptr pa_mainloop_api; e: ptr pa_time_event;
                           tv: ptr timeval; userdata: pointer)
  pa_time_event_destroy_cb_t* = proc (a: ptr pa_mainloop_api; e: ptr pa_time_event;
                                   userdata: pointer)
  pa_defer_event_cb_t* = proc (a: ptr pa_mainloop_api; e: ptr pa_defer_event;
                            userdata: pointer)
  pa_defer_event_destroy_cb_t* = proc (a: ptr pa_mainloop_api; e: ptr pa_defer_event;
                                    userdata: pointer)

  pa_context_index_cb_t* = proc(c: ptr pa_context; idx: uint32; userdata: pointer) {.cdecl.}
  pa_context_notify_cb_t* = proc(c: ptr pa_context, userdata: pointer) {.cdecl.}


  pa_mainloop_api* {.bycopy, pulse, header: "<pulse/mainloop-api.h>".} = object
    userdata*: pointer
    io_new*: proc (a: ptr pa_mainloop_api; fd: cint; events: pa_io_event_flags_t;
                 cb: pa_io_event_cb_t; userdata: pointer): ptr pa_io_event
    io_enable*: proc (e: ptr pa_io_event; events: pa_io_event_flags_t)
    io_free*: proc (e: ptr pa_io_event)
    io_set_destroy*: proc (e: ptr pa_io_event; cb: pa_io_event_destroy_cb_t)
    time_new*: proc (a: ptr pa_mainloop_api; tv: ptr timeval; cb: pa_time_event_cb_t;
                   userdata: pointer): ptr pa_time_event
    time_restart*: proc (e: ptr pa_time_event; tv: ptr timeval)
    time_free*: proc (e: ptr pa_time_event)
    time_set_destroy*: proc (e: ptr pa_time_event; cb: pa_time_event_destroy_cb_t)
    defer_new*: proc (a: ptr pa_mainloop_api; cb: pa_defer_event_cb_t;
                    userdata: pointer): ptr pa_defer_event
    defer_enable*: proc (e: ptr pa_defer_event; b: cint)
    defer_free*: proc (e: ptr pa_defer_event)
    defer_set_destroy*: proc (e: ptr pa_defer_event; cb: pa_defer_event_destroy_cb_t)
    quit*: proc (a: ptr pa_mainloop_api; retval: cint)

  pa_context_state_t* = enum
    PA_CONTEXT_UNCONNECTED,
    PA_CONTEXT_CONNECTING,
    PA_CONTEXT_AUTHORIZING,
    PA_CONTEXT_SETTING_NAME,
    PA_CONTEXT_READY,
    PA_CONTEXT_FAILED,
    PA_CONTEXT_TERMINATED
  
  pa_spawn_api* {.bycopy, pulse, header: "<pulse/def.h>".} = object
    prefork*: proc() {.cdecl.}
    postfork*: proc() {.cdecl.}
    atfork*: proc() {.cdecl.}

  pa_context_flags_t* = enum
    PA_CONTEXT_NOFLAGS,
    PA_CONTEXT_NOAUTOSPAWN,
    PA_CONTEXT_NOFAIL


proc pa_mainloop_new: ptr pa_mainloop {.pulse, header: "<pulse/mainloop.h>".}
proc pa_mainloop_free(m: ptr pa_mainloop) {.pulse, header: "<pulse/mainloop.h>".}
proc pa_mainloop_quit(m: ptr pa_mainloop, retval: cint) {.pulse, header: "<pulse/mainloop.h>".}
proc pa_context_new(mainloop: ptr pa_mainloop, name: cstring): ptr pa_context {.pulse, header: "<pulse/context.h>".}
proc pa_mainloop_get_api(m: ptr pa_mainloop): ptr pa_mainloop_api {.pulse, header: "<pulse/mainloop.h>".}
proc pa_context_load_module(c: ptr pa_context, name: cstring, argument: cstring, cb: pa_context_index_cb_t, userdata: pointer): ptr pa_operation {.pulse, header: "<pulse/introspect.h>".}
proc pa_context_errno(c: ptr pa_context): cint {.pulse, header: "<pulse/context.h>".}
proc pa_strerror(error: cint): cstring {.pulse, header: "<pulse/error.h>".}
proc pa_context_set_state_callback(c: ptr pa_context, cb: pa_context_notify_cb_t, userdata: pointer) {.pulse, header: "<pulse/context.h>".}
proc pa_context_get_state(c: ptr pa_context): pa_context_state_t {.pulse, header: "<pulse/context.h>".}
proc pa_proplist_new: ptr pa_proplist {.pulse, header: "<pulse/proplist.h>".}
proc pa_context_new_with_proplist(mainloop: ptr pa_mainloop_api, name: cstring, proplist: ptr pa_proplist): ptr pa_context {.pulse, header: "<pulse/context.h>".}
proc pa_context_connect(c: ptr pa_context, server: cstring, flags: pa_context_flags_t, api: ptr pa_spawn_api): cint {.pulse, header: "<pulse/context.h>".}
proc pa_mainloop_run(m: ptr pa_mainloop, retval: ptr cint): cint {.pulse, header: "<pulse/mainloop.h>".}


template abort =
  let errno {.inject.} = pa_context_errno(context)
  echo &"[ERRNO] {errno}: ", pa_strerror(errno)
  quit(1)

echo "[-] Creating mainloop"
let mainloop = pa_mainloop_new()
echo "[-] pa_mainloop address: ", repr(mainloop)

echo "[-] Getting pa_mainloop_api"
let mainloop_api = pa_mainloop_get_api(mainloop)
echo "[-] pa_mainloop_api address: ", repr(mainloop_api)

echo "[-] Creating a context"
var context = pa_context_new(mainloop, name = cstring"test_context")
echo "[-] pa_context address: ", repr(context)

proc index_callback(c: ptr pa_context, idx: uint32, userdata: pointer) {.cdecl.} =
  echo "Inside index callback"

  if idx == PA_INVALID_INDEX:
    let error = pa_strerror(pa_context_errno(c))
    echo "[FATAL] ", $error
    # pa_log("Failure: %s", error)
    quit(1)

  echo "{+} Idx: ", idx

proc context_state_callback(c: ptr pa_context, userdata: pointer) {.cdecl.} =
  echo "Context state callback called"

  case pa_context_get_state(c):
  of {PA_CONTEXT_CONNECTING, PA_CONTEXT_AUTHORIZING, PA_CONTEXT_SETTING_NAME}:
    discard
  of PA_CONTEXT_READY:
    echo "[-] Loading module-null-sink"
    let operation = pa_context_load_module(context, name = cstring"module-null-sink", argument=cstring"sink_name=test", index_callback, nil)
    echo "[-] pa_operation address: ", repr(operation)

    if operation.isNil:
      echo "[FATAL] pa_operation is nil (maybe you passed wrong argument param)"
      abort()
  else:
    echo "[WARN] Ignoring {PA_CONTEXT_UNCONNECTED, PA_CONTEXT_FAILED, PA_CONTEXT_TERMINATED}"

echo "[-] Creating proplist"
let proplist = pa_proplist_new()

echo "[-] Updating context with proplist"
context = pa_context_new_with_proplist(mainloop_api, nil, proplist)
echo "[-] pa_context (updated with proplist) address: ", repr(context)

echo "[-] Setting state callback"
pa_context_set_state_callback(context, context_state_callback, nil)

echo "[-] Connecting context to (default = nil) server"
if pa_context_connect(context, server = nil, PA_CONTEXT_NOFLAGS, nil) == -1:
  echo "[FATAL] pa_context_connect returned -1"
  abort()

var ret: cint = 0
echo "[RUNNING] Running event loop!"
if pa_mainloop_run(mainloop, addr(ret)) == -1:
  echo "[FATAL] pa_mainloop_run returned -1"
  abort()

let retval: cint = 0
echo &"[-] Quitting mainloop with {retval=}"
pa_mainloop_quit(mainloop, retval)

echo "[-] Freeing mainloop pointer"
pa_mainloop_free(mainloop)

echo &"[-] Done! pa_mainloop_run returned exit code: `{ret}`" 
