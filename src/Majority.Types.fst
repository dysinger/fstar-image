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
open FStar.List.Tot

module U32 = FStar.UInt32
module Seq = FStar.Seq

(** The element type: a 32-bit unsigned word (e.g. a voter's candidate id). *)
type elem = U32.t

(** The *extracted* result of a candidate pass: either there is no majority
    candidate (the sequence was empty) or a surviving candidate.  This is an
    F*-defined variant (not the stdlib [option]), so Custard's F# backend has
    a realization for it — the stdlib [option] is hand-written OCaml with no
    F# counterpart.  [vote_result_of_option] bridges the concise pure spec
    ([Majority.find_candidate] : [option elem]) to this extractable form. *)
noeq type vote_result =
  | VR_NoMajority
  | VR_Majority: (cand: elem) -> vote_result

(** Bridges the pure [option] spec to the extractable [vote_result]. *)
let vote_result_of_option (o: option elem) : vote_result =
  match o with
  | None -> VR_NoMajority
  | Some c -> VR_Majority c

(** [count x s] — the number of occurrences of [x] in [s]. *)
let count (x: elem) (s: Seq.seq elem) : nat =
  List.Tot.count x (Seq.seq_to_list s)

(** [majority x s] — [x] is a majority element of [s]: it occurs strictly
    more than half the time. *)
let majority (x: elem) (s: Seq.seq elem) : prop =
  count x s > Seq.length s / 2

(** A sequence has at most one majority element (the core uniqueness fact). *)

(** [count] of the empty sequence is zero (the base case the Pulse leaf
    starts its scan from). *)
let lemma_count_empty (x: elem)
  : Lemma (count x Seq.empty == 0)
  = ()

(** [majority] is a *prop* — proofs about it are erased before extraction.
    The only runtime-relevant definitions in this module are [count], which
    the algorithm module re-uses to define the verification pass. *)
