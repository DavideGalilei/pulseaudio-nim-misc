#[
  Hear yourself talking. Nim translation of both the examples
  in the official pulseaudio documentation for developers.
  https://freedesktop.org/software/pulseaudio/doxygen/examples.html
]#

import std / sequtils

{.passL: "-lpulse -lpulse-simple".}

{.pragma: pulse, header: "<pulse/simple.h>", importc: "$1".}


type
  pa_stream_direction_t* {.pulse.} = enum
    PA_STREAM_NODIRECTION,    ## *< Invalid direction
    PA_STREAM_PLAYBACK,       ## *< Playback stream
    PA_STREAM_RECORD,         ## *< Record stream
    PA_STREAM_UPLOAD          ## *< Sample upload stream

  pa_sample_format_t* {.pulse.} = enum
    PA_SAMPLE_INVALID = -1, ## *< An invalid value
    PA_SAMPLE_U8, ## *< Unsigned 8 Bit PCM
    PA_SAMPLE_ALAW,           ## *< 8 Bit a-Law
    PA_SAMPLE_ULAW,           ## *< 8 Bit mu-Law
    PA_SAMPLE_S16LE,          ## *< Signed 16 Bit PCM, little endian (PC)
    PA_SAMPLE_S16BE,          ## *< Signed 16 Bit PCM, big endian
    PA_SAMPLE_FLOAT32LE,      ## *< 32 Bit IEEE floating point, little endian (PC), range -1.0 to 1.0
    PA_SAMPLE_FLOAT32BE,      ## *< 32 Bit IEEE floating point, big endian, range -1.0 to 1.0
    PA_SAMPLE_S32LE,          ## *< Signed 32 Bit PCM, little endian (PC)
    PA_SAMPLE_S32BE,          ## *< Signed 32 Bit PCM, big endian
    PA_SAMPLE_S24LE,          ## *< Signed 24 Bit PCM packed, little endian (PC). \since 0.9.15
    PA_SAMPLE_S24BE,          ## *< Signed 24 Bit PCM packed, big endian. \since 0.9.15
    PA_SAMPLE_S24_32LE,       ## *< Signed 24 Bit PCM in LSB of 32 Bit words, little endian (PC). \since 0.9.15
    PA_SAMPLE_S24_32BE, ## *< Signed 24 Bit PCM in LSB of 32 Bit words, big endian. \since 0.9.15
                       ##  Remeber to update
                       ##  https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/SupportedAudioFormats/
                       ##  when adding new formats!
    PA_SAMPLE_MAX             ## *< Upper limit of valid sample types

  pa_sample_spec {.pulse.} = object
    format: pa_sample_format_t
    rate: uint32
    channels: uint8    

  pa_channel_map {.pulse.} = object
  pa_buffer_attr {.pulse.} = object

  pa_simple = pointer

#[
typedef struct pa_sample_spec {
  pa_sample_format_t format;
  /**< The sample format */

  uint32_t rate;
  /**< The sample rate. (e.g. 44100) */

  uint8_t channels;
  /**< Audio channels. (1 for mono, 2 for stereo, ...) */
} pa_sample_spec;
]#

proc pa_simple_new(
  server: cstring,
  name: cstring,
  dir: pa_stream_direction_t,
  dev: cstring,
  stream_name: cstring,
  ss: ptr pa_sample_spec,
  map: ptr pa_channel_map,
  attr: ptr pa_buffer_attr,
  error: ptr cint, 
): pa_simple {.pulse.}

proc pa_strerror(error: ptr cint): cstring {.pulse.}
proc pa_simple_free(pa: pa_simple) {.pulse.}
proc pa_simple_read(s: pa_simple, data: pointer, bytes: csize_t, error: ptr cint): cint {.pulse.}
proc pa_simple_write(s: pa_simple, data: pointer, bytes: csize_t, error: ptr cint): cint {.pulse.}
proc pa_simple_drain(s: pa_simple, error: ptr cint): cint {.pulse.}


var error: cint
template errorcheck() =
  echo "Error value: ", error
  echo "Error str: ", if error != 0: $pa_strerror(addr error) else : "none"
  if error != 0:
    echo "Quitting for error..."
    quit(1)

var spec = pa_sample_spec(
  format: PA_SAMPLE_S16LE,
  rate: 44100,
  channels: 2,
)

#[let pa = pa_simple_new(
  nil,
  cstring"test_api",
  cast[pa_stream_direction_t](1),
  nil,
  cstring"playback",
  addr(spec),
  nil,
  nil,
  addr(error),
)

echo "pa_simple addr: ", repr(pa)
errorcheck()

var bytes: seq[uint8] = toSeq(0'u8 .. 255'u8)

echo "Write result: ", pa_simple_write(pa, addr(bytes[0]), cint(len(bytes)), addr(error))
errorcheck()

pa_simple_free(pa)
]#

let recording = pa_simple_new(nil, "RecordingDevice", PA_STREAM_RECORD, nil, cstring"record", addr(spec), nil, nil, addr(error))
errorcheck()

let playback = pa_simple_new(nil, "PlaybackDevice", PA_STREAM_PLAYBACK, nil, "playback", addr(spec), nil, nil, addr(error))
errorcheck()

var buffer: array[1024, uint8]

setControlCHook(proc {.noconv.} =
  if pa_simple_drain(playback, addr(error)) != 0:
    errorcheck()

  pa_simple_free(recording)
  pa_simple_free(playback)
)

while true:
  if pa_simple_read(recording, addr(buffer[0]), csize_t(sizeof(buffer)), addr(error)) != 0:
    errorcheck()

  if pa_simple_write(playback, addr(buffer[0]), csize_t(sizeof(buffer)), addr(error)) != 0:
    errorcheck()

  # if loop_write(STDOUT_FILENO, addr(buffer[0]), sizeof(buffer)) != sizeof(buffer):
  #   echo "An error occurred: ", $strerror(errno)
  #   quit(1)
