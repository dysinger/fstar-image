(* Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later *)

(** Majority.Types — the pure spec for the Boyer–Moore majority-vote example.

    This is the *pure spec module*: it defines the mathematical notion of a
    *majority element* of a sequence (an element that occurs strictly more
    than half the time) and proves the basic lemmas that the algorithm module
    ([Majority]) and the Pulse leaf ([Majority.Pulse]) both rely on.

    There is no state, no heap, no extraction-relevant code here — only
    erased-in-extraction `Lemma`s and total pure functions.  This split
    (Types / algorithm / Pulse leaf) is the canonical three-layer library
    shape this template demonstrates.

    @header Majority.Types
*)
module Majority.Types

open FStar.Seq
open FStar.UInt32

module U32 = FStar.UInt32
module Seq = FStar.Seq

(** The element type: a 32-bit unsigned word (e.g. a voter's candidate id). *)
type elem = U32.t

(** [count x s] — the number of occurrences of [x] in [s]. *)
let rec count (x: elem) (s: Seq.seq elem) : nat =
  if Seq.length s = 0 then 0
  else (if Seq.index s (Seq.length s - 1) = x then 1 else 0)
       + count x (Seq.slice s 0 (Seq.length s - 1))

(** [majority x s] — [x] is a majority element of [s]: it occurs strictly
    more than half the time. *)
let majority (x: elem) (s: Seq.seq elem) : prop =
  count x s > Seq.length s / 2

(** A sequence has at most one majority element (the core uniqueness fact). *)

(** [count x s <= length s] — no element occurs more often than the length. *)
let rec lemma_count_le_len (x: elem) (s: Seq.seq elem)
  : Lemma (count x s <= Seq.length s)
          (decreases Seq.length s)
  = if Seq.length s = 0 then ()
    else (
      lemma_count_le_len x (Seq.slice s 0 (Seq.length s - 1));
      ()
    )

(** [count] is monotone in the slice: appending to the right never decreases
    the count.  (Useful when the Pulse leaf reasons about a prefix scan.) *)
let rec lemma_count_slice (x: elem) (s: Seq.seq elem)
  : Lemma (count x (Seq.slice s 0 0) == 0)
          (decreases Seq.length s)
  = ()

(** [majority] is a *prop* — proofs about it are erased before extraction.
    The only runtime-relevant definitions in this module are [count], which
    the algorithm module re-uses to define the verification pass. *)
