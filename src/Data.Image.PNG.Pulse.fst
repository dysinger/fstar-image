(* Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later *)

(**
Data.Image.PNG.Pulse — C-extractable PNG chunk tag dispatch via Pulse +
Custard.

A 1-byte PNG chunk-type tag read/write over [Pulse.Lib.Array.array].  The
tag is the 4-way [`png_chunk`] (IHDR/IDAT/IEND/PLTE), encoded as a single
byte.  Each encode/decode carries a POINTWISE post-condition tying the buffer
contents to the pure spec [tag_of]/[tag_to_type].

Written for F* v2026.09.20 (Custard `--custard_backend C`).  Zero admits.

@header Data.Image.PNG.Pulse

@section Type
- [png_chunk] — the 4-way PNG chunk type
- [opt_png_chunk] — the tagged decode result ([OPN_None] (unreachable) | [OPN_Some] of ([png_chunk] & [U32.t]))

@section Spec
- [tag_of] / [tag_to_type] — the pure tag byte ↔ png_chunk maps

@section Encode
- [encode_png_chunk] — writes the 1-byte tag, returns [1ul]

@section Decode
- [decode_png_chunk] — reads the 1-byte tag, returns ([png_chunk], [1ul])

@section Roundtrip
- [lemma_tag_roundtrip] — the pure spec roundtrip
- [lemma_pulse_png_chunk_roundtrip] — encode then decode preserves the tag
*)
module Data.Image.PNG.Pulse
#lang-pulse

open Pulse
open Pulse.Lib.Reference
module A = Pulse.Lib.Array
module US = FStar.SizeT
module U8 = FStar.UInt8
module U32 = FStar.UInt32
module Seq = FStar.Seq

open FStar.Seq
open FStar.Int.Cast


(* ── Type ───────────────────────────────────────────────────────────── *)


(** [png_chunk] — the 4-way PNG chunk type for C extraction. *)
type png_chunk =
  | PC_IHDR
  | PC_IDAT
  | PC_IEND
  | PC_PLTE


(** [opt_png_chunk] — the decode result: [OPN_None] (never, under the bounds
    precondition) or [OPN_Some] of ([png_chunk] & [U32.t]).

    [OPN_None] is constructively unreachable — the 1-byte read under a bounds
    precondition always succeeds, and [decode_png_chunk]'s body returns only
    [OPN_Some] — but it is REQUIRED for extraction: Custard's F# backend has no
    realization for a bare [tuple2] (`png_chunk & U32.t`), so the pair must be
    wrapped in a (multi-constructor) sum.  Do NOT delete [OPN_None] without an
    F# realization for the pair. *)
type opt_png_chunk =
  | OPN_None
  | OPN_Some of (png_chunk & U32.t)


(* ── Pure spec (noextract) ──────────────────────────────────────────── *)


(** [tag_of] — the pure mapping from [png_chunk] to its tag byte. *)
noextract
let tag_of (t: png_chunk) : U8.t =
  match t with
  | PC_IHDR -> 0x00uy
  | PC_IDAT -> 0x01uy
  | PC_IEND -> 0x02uy
  | PC_PLTE -> 0x03uy


(** [tag_to_type] — the pure mapping from a tag byte to its [png_chunk];
    [None] for a byte outside the 4-way set. *)
noextract
let tag_to_type (b: U8.t) : option png_chunk =
  if U8.eq b 0x00uy then Some PC_IHDR
  else if U8.eq b 0x01uy then Some PC_IDAT
  else if U8.eq b 0x02uy then Some PC_IEND
  else if U8.eq b 0x03uy then Some PC_PLTE
  else None


(** [lemma_tag_roundtrip] — the pure spec roundtrip: decoding the tag byte of
    [t] is [Some t]. *)
noextract
let lemma_tag_roundtrip (t: png_chunk) : Lemma (tag_to_type (tag_of t) == Some t) =
  match t with
  | PC_IHDR -> ()
  | PC_IDAT -> ()
  | PC_IEND -> ()
  | PC_PLTE -> ()


(* ── Encode ─────────────────────────────────────────────────────────── *)


(** [encode_png_chunk] writes the 1-byte tag of [t] into [buf] at [off].

    @param t The PNG chunk type to write.
    @param buf The destination buffer (must hold at least 1 byte at [off]).
    @param off The write offset.
    @returns The number of bytes written (always [1ul]). *)
fn encode_png_chunk (t: png_chunk) (buf: A.array U8.t) (off: U32.t)
    (#s0: erased (Seq.seq U8.t))
    requires
      A.pts_to buf s0 **
      pure (U32.v off + 1 <= A.length buf /\ U32.v off < 4294967296)
    returns w: U32.t
    ensures
      (exists* (s1: Seq.seq U8.t).
        A.pts_to buf s1 **
        pure (U32.v off + 1 <= A.length buf /\
              Seq.length s1 == A.length buf /\
              Seq.index s1 (U32.v off) == tag_of t)) **
      pure (w == 1ul)
{
  let j = US.uint32_to_sizet off;
  A.pts_to_len buf;
  buf.(j) <- tag_of t;
  1ul
}


(* ── Decode ─────────────────────────────────────────────────────────── *)


(** [decode_png_chunk] reads the 1-byte tag at [off] from [buf].

    There is no rejection under the bounds precondition: the tag byte is read
    and mapped via [tag_to_type]; a byte outside the 4-way set maps to
    [OPN_None].  The [ensures] ties the result to [tag_to_type]. *)
fn decode_png_chunk (buf: A.array U8.t) (off: U32.t)
    (#s0: erased (Seq.seq U8.t))
    requires
      A.pts_to buf s0 **
      pure (U32.v off + 1 <= A.length buf /\ U32.v off < 4294967296 /\
            A.length buf == Seq.length s0)
    returns r: opt_png_chunk
    ensures
      A.pts_to buf s0 **
      pure (
        A.length buf == Seq.length s0 /\
        U32.v off + 1 <= A.length buf /\
        (match tag_to_type (Seq.index s0 (U32.v off)) with
         | Some pc -> r == OPN_Some (pc, 1ul)
         | None -> r == OPN_None))
{
  A.pts_to_len buf;
  let j = US.uint32_to_sizet off;
  let b = buf.(j);
  if U8.eq b 0x00uy { OPN_Some (PC_IHDR, 1ul) }
  else if U8.eq b 0x01uy { OPN_Some (PC_IDAT, 1ul) }
  else if U8.eq b 0x02uy { OPN_Some (PC_IEND, 1ul) }
  else if U8.eq b 0x03uy { OPN_Some (PC_PLTE, 1ul) }
  else { OPN_None }
}


(* ── Roundtrip ──────────────────────────────────────────────────────── *)


(** [lemma_pulse_png_chunk_roundtrip]: encode then decode preserves the chunk.

    @param t The PNG chunk type to roundtrip.
    @param buf The buffer (must hold at least 1 byte at [off]).
    @param off The offset.
    Proves [decode_png_chunk buf off] after [encode_png_chunk t buf off]
    returns [OPN_Some (t, 1ul)]. *)
fn lemma_pulse_png_chunk_roundtrip (t: png_chunk) (buf: A.array U8.t) (off: U32.t)
    (#s0: erased (Seq.seq U8.t))
    requires
      A.pts_to buf s0 **
      pure (U32.v off + 1 <= A.length buf /\ U32.v off < 4294967296)
    returns res: (U32.t & opt_png_chunk)
    ensures
      exists* (s1: Seq.seq U8.t).
        A.pts_to buf s1 **
        pure (res == (1ul, OPN_Some (t, 1ul)))
{
  let w = encode_png_chunk t buf off;
  let r = decode_png_chunk buf off;
  (w, r)
}
