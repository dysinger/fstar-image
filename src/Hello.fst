(** Hello — a minimal verified F* module that extracts to C (KaRaMeL) and
    runs natively or in WebAssembly.

    The module demonstrates the full verification workflow end to end:

      - a small library of total, verified byte operations;
      - lemmas proving algebraic properties of those operations at
        verification time (never executed — they are erased before C
        extraction);
      - a Low* `main` entry point that exercises the verified operations and
        returns a process exit code, extractable both to a native binary and
        to a WebAssembly module driven by KaRaMeL's JS loader.

    Layout for the two-layer pattern (see the F* low-star skill): the pure
    `Tot` functions and the `Lemma`-typed proofs form the specification layer;
    the `main` function is the single Low* (`St`) entry point.

    @header Hello
*)
module Hello

open FStar.UInt8
open FStar.Int32
open FStar.HyperStack.ST

(** Local alias for the byte type used throughout this module. *)
module U8 = FStar.UInt8

(** Verified byte operations *)

(** The byte 0x00. *)
let zero = 0x00uy

(** Adds two bytes, reduced modulo 256.

    [U8.add_mod] performs modular addition; the result is always a valid byte,
    with no possibility of overflow past the byte range.

    @param a First byte.
    @param b Second byte.
    @returns The sum [a + b] reduced modulo 256. *)
inline_for_extraction
let add (a b: U8.t) : U8.t = U8.add_mod a b

(** Bitwise-XORs two bytes.

    XOR is its own inverse and is used throughout this module to demonstrate
    an involutive operation that is cheap to verify.

    @param a First byte.
    @param b Second byte.
    @returns The bitwise XOR [a lxor b]. *)
inline_for_extraction
let xor (a b: U8.t) : U8.t = U8.logxor a b

(** Verification lemmas *)

(** Addition of bytes is commutative: [add a b == add b a].

    The proof is discharged by the SMT solver directly from the definition of
    [U8.add_mod] — addition of the underlying machine integers is commutative,
    and reduction modulo 256 preserves that symmetry.

    @param a First byte.
    @param b Second byte. *)
let lemma_add_commutes (a b: U8.t) : Lemma (add a b == add b a) =
  ()

(** XOR is involutive: masking twice with the same byte recovers the input.

    For any bytes [a] and [b], [xor (xor a b) b == a].  The proof forwards to
    the standard library lemma [FStar.UInt.logxor_inv] and bridges back through
    the [UInt8] wrapper with [FStar.UInt8.vu_inv].

    @param a First byte.
    @param b The mask byte. *)
let lemma_xor_involutive (a b: U8.t) : Lemma (xor (xor a b) b == a) =
  FStar.UInt.logxor_inv #8 (U8.v a) (U8.v b);
  U8.vu_inv (FStar.UInt.logxor #8 (FStar.UInt.logxor #8 (U8.v a) (U8.v b)) (U8.v b))

(** The runnable entry point *)

(** The process entry point.

    [main] exercises the verified operations: it computes [add 10 20] and
    [xor 0xFF 0x0A] (both proven properties above hold for any bytes) and
    returns the process exit code [0] (success) as an [Int32], the shape the
    KaRaMeL wasm loader expects for a runnable entry point.  It deliberately
    does NOT call the ghost lemmas above — those are verification-time proofs,
    erased before extraction; a runnable entry point uses the verified
    operations, not the proofs.  KaRaMeL extracts this function to a `main`
    export that both the native driver and the WebAssembly JS loader invoke.

    @returns [0l] when the program runs to completion. *)
let main () : St Int32.t =
  let _ = add 0x0Auy 0x14uy in  (* 10 + 20: add is proven commutative *)
  let _ = xor 0xFFuy 0x0Auy in  (* 0xFF ^ 0x0A: xor is proven involutive *)
  0l
