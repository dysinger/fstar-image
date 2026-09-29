(* Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later *)

(** Example.Majority.CLI — the command-line entry point of the Boyer–Moore example.

    [main] builds a small, *static* vote sequence (a compile-time constant),
    runs [Example.Majority.Pulse.majority_vote] over it, and returns a process
    exit status: [0] when the extracted scan finds the expected majority
    element ([2]), [1] otherwise.  Custard compiles it with
    `--custard_main Example.Majority.CLI.main` into a standalone C program.

    The sequence lives in the program image (`Pulse.Lib.GlobalArray`), so
    there is no runtime allocation — the array is read-only, which matches the
    Boyer–Moore candidate pass (it never writes).  This makes
    [Example.Majority.CLI] the *consumer* of the [Example.Majority.Pulse] leaf,
    exercising the exact C-API a downstream linker would call.

    @header Example.Majority.CLI
*)
module Example.Majority.CLI
#lang-pulse

open Pulse
open Pulse.Lib.Reference
module A = Pulse.Lib.Array
module G = Pulse.Lib.GlobalArray
module US = FStar.SizeT
module U32 = FStar.UInt32
module I32 = FStar.Int32
open Example.Majority.Types

(** A fixed vote sequence: [2; 2; 1; 2; 1; 2].  The majority element is [2]. *)
(** The vote table as a top-level static array.  (Custard requires a static
    array's braced initializer to be the body of a top-level definition, which
    becomes the C `static const uint32_t ...[] = { ... };` declaration; only
    the *pointer* conversion {!G.array_of_static_array} may appear inline.) *)
let votes =
  G.mk_static_array [2ul; 2ul; 1ul; 2ul; 1ul; 2ul]

divergent
fn main ()
  returns x: I32.t
{
  let arr = G.array_of_static_array votes;
  with p s. assert (A.pts_to arr #p s);
  A.pts_to_len arr;
  let r = Example.Majority.Pulse.majority_vote arr 6ul;
  with p s. assert (A.pts_to arr #p s);
  drop_ (A.pts_to arr #p s);
  match r {
    VR_Majority c -> { if (U32.eq c 2ul) { 0l } else { 1l } }
    VR_NoMajority -> { 1l }
  }
}
