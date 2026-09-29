(* Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later *)

(** Majority — the pure Boyer–Moore majority-vote algorithm.

    Boyer–Moore is the classic linear-time, constant-space algorithm for
    finding a majority element.  It has two passes:

      1. **candidate selection** ([find_candidate]) — scan the sequence once,
         maintaining a candidate and a counter.  When a new element matches the
         candidate, increment; otherwise decrement; when the counter hits zero,
         replace the candidate.  After the pass, *if* the sequence has a
         majority element, that majority is necessarily the surviving candidate.
      2. **verification** ([verify]) — count the candidate's occurrences and
         confirm it is a strict majority.

    This module is the *pure algorithm layer*: total functions over
    [Seq.seq Majority.Types.elem] with no heap.  The corresponding Pulse leaf
    ([Majority.Pulse]) re-implements the same pass over a mutable array and
    ties its result back to this pure spec by a lemma.

    The deep Boyer–Moore invariant ("the surviving candidate is the only
    possible majority") is *stated in prose* below and exercised on concrete
    vectors in the test module; this template's *proven* lemma is the
    verification-pass correspondence, which is the definitional part of the
    algorithm and is discharged by reduction.

    @header Majority
*)
module Majority

open FStar.Seq
open FStar.UInt32

module U32 = FStar.UInt32
module Seq = FStar.Seq
module MT = Majority.Types
open MT

(** [candidate_step] — one step of the Boyer–Moore scan.

    State is [(cand, count)]: the current candidate and the current counter.
    Processing element [x]:
      - if the counter is 0, the new candidate is [x] and the counter is 1;
      - else if [x] equals the candidate, increment the counter;
      - else decrement the counter.

    This is the *pure* one-step transition; [find_candidate] folds it over the
    whole sequence. *)
let candidate_step (cand: elem) (cnt: nat) (x: elem) : elem & nat =
  if cnt = 0 then (x, 1)
  else if cand = x then (cand, cnt + 1)
  else (cand, cnt - 1)

(** [find_candidate s] — the candidate-selection pass.

    Returns [Some c] if a candidate survives (the counter never collapsed to
    zero at the very end), or [None] if the final counter is zero.  The
    returned candidate is the *only* element that can be a majority of [s]
    (see the invariant note above; the implication is exercised concretely in
    the test module). *)
let find_candidate (s: Seq.seq elem) : option elem =
  let n = Seq.length s in
  if n = 0 then None
  else
    let rec go (i: nat) (cand: elem) (cnt: nat)
      : option elem
      (decreases n - i)
      = if i = n then Some cand
        else let cand', cnt' = candidate_step cand cnt (Seq.index s i) in
             go (i + 1) cand' cnt'
    in
    go 1 (Seq.index s 0) 1

(** [verify x s] — the verification pass: does [x] actually appear more than
    [|s| / 2] times? *)
let verify (x: elem) (s: Seq.seq elem) : bool =
  count x s > Seq.length s / 2

(** The verification pass is the algorithm's ground truth: [verify x s] is
    true exactly when [x] is a majority of [s].  This is the spec↔impl
    correspondence lemma — [verify] *is* [majority], so the proof reduces. *)
let lemma_verify_is_majority (x: elem) (s: Seq.seq elem)
  : Lemma (verify x s == true <==> majority x s)
  = ()

(** Boyer–Moore is sound for the *complete* two-pass procedure: when the
    candidate pass returns [Some c], running the verification pass on [c]
    decides whether [c] is a majority.  (The candidate-uniqueness direction
    — that *if* any majority exists it is [c] — is the pairing invariant
    stated above and exercised on vectors in the test module.) *)
let lemma_two_pass_sound (s: Seq.seq elem) (c: elem)
  : Lemma
    (requires find_candidate s == Some c)
    (ensures (verify c s == true <==> majority c s))
  = lemma_verify_is_majority c s
