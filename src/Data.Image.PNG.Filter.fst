(*
   Data.Image.PNG.Filter — PNG filter algorithms
   Copyright 2026 Department of Code LLC. All rights reserved.

   Implements PNG filter types per ISO/IEC 15948:2004 section 9.
   FilterNone fully verified; Sub/Up/Average/Paeth stubbed for v0.2.
*)
module Data.Image.PNG.Filter

open Data.Codec
open FStar.Mul
open Data.Image
open FStar.List.Tot

(* ========================================================================
   SECTION 1: Filter Type
   ======================================================================== *)

type filter_type =
  | FilterNone
  | FilterSub
  | FilterUp
  | FilterAverage
  | FilterPaeth

let filter_byte (f: filter_type) : byte =
  match f with
  | FilterNone    -> 0x00uy
  | FilterSub     -> 0x01uy
  | FilterUp      -> 0x02uy
  | FilterAverage -> 0x03uy
  | FilterPaeth   -> 0x04uy

(* ========================================================================
   SECTION 2: Helper — Paeth Predictor
   ======================================================================== *)

let paeth_predictor (a b c: byte) : byte =
  let open FStar.UInt8 in
  let v_a = v a in
  let v_b = v b in
  let v_c = v c in
  let p  = v_a + v_b - v_c in
  let pa = abs (p - v_a) in
  let pb = abs (p - v_b) in
  let pc = abs (p - v_c) in
  if pa <= pb && pa <= pc then a
  else if pb <= pc then b
  else c

(* ========================================================================
   SECTION 3: Filter Encode — filter_scanline
   ======================================================================== *)

let rec filter_sub_aux (cur: list byte) (prev: list byte) (bpp: nat) (i: nat)
  : Tot (list byte) (decreases cur) =
  match cur with
  | [] -> []
  | x :: xs ->
    (* (a) TODO: implement Sub filter — compute byte a = bpp positions left in cur *)
    admit(); x :: filter_sub_aux xs prev bpp (i + 1)

let rec filter_up_aux (cur: list byte) (prev: list byte) (bpp: nat) (i: nat)
  : Tot (list byte) (decreases cur) =
  match cur with
  | [] -> []
  | x :: xs ->
    (* (a) TODO: implement Up filter — Filt(x) = Orig(x) - Orig(b) *)
    admit(); x :: filter_up_aux xs prev bpp (i + 1)

let rec filter_average_aux (cur: list byte) (prev: list byte) (bpp: nat) (i: nat)
  : Tot (list byte) (decreases cur) =
  match cur with
  | [] -> []
  | x :: xs ->
    (* (a) TODO: implement Average filter — Filt(x) = Orig(x) - floor((Orig(a)+Orig(b))/2) *)
    admit(); x :: filter_average_aux xs prev bpp (i + 1)

let rec filter_paeth_aux (cur: list byte) (prev: list byte) (bpp: nat) (i: nat)
  : Tot (list byte) (decreases cur) =
  match cur with
  | [] -> []
  | x :: xs ->
    (* (a) TODO: implement Paeth filter — Filt(x) = Orig(x) - PaethPredictor(Orig(a),Orig(b),Orig(c)) *)
    admit(); x :: filter_paeth_aux xs prev bpp (i + 1)

let filter_scanline (f: filter_type) (cur: list byte) (prev: list byte) (bpp: nat)
  : list byte =
  match f with
  | FilterNone ->
    (* FilterNone: pass through, prepend filter byte 0x00 *)
    filter_byte FilterNone :: cur
  | FilterSub ->
    (* (a) TODO: implement Sub filter — Filt(x) = Orig(x) - Orig(a) *)
    let filtered = filter_sub_aux cur prev bpp 0 in
    filter_byte FilterSub :: filtered
  | FilterUp ->
    (* (a) TODO: implement Up filter — Filt(x) = Orig(x) - Orig(b) *)
    let filtered = filter_up_aux cur prev bpp 0 in
    filter_byte FilterUp :: filtered
  | FilterAverage ->
    (* (a) TODO: implement Average filter — Filt(x) = Orig(x) - floor((Orig(a)+Orig(b))/2) *)
    let filtered = filter_average_aux cur prev bpp 0 in
    filter_byte FilterAverage :: filtered
  | FilterPaeth ->
    (* (a) TODO: implement Paeth filter — Filt(x) = Orig(x) - PaethPredictor(Orig(a),Orig(b),Orig(c)) *)
    let filtered = filter_paeth_aux cur prev bpp 0 in
    filter_byte FilterPaeth :: filtered

(* ========================================================================
   SECTION 4: Filter Decode — reconstruct_scanline
   ======================================================================== *)

let rec reconstruct_sub_aux (cur: list byte) (prev: list byte) (bpp: nat) (recon: list byte) (i: nat)
  : Tot (option (list byte)) (decreases cur) =
  match cur with
  | [] -> Some (List.rev recon)
  | x :: xs -> admit() (* (a) TODO: implement Sub reconstruction — Recon(x) = Filt(x) + Recon(a) *)

let rec reconstruct_up_aux (cur: list byte) (prev: list byte) (bpp: nat) (recon: list byte) (i: nat)
  : Tot (option (list byte)) (decreases cur) =
  match cur with
  | [] -> Some (List.rev recon)
  | x :: xs -> admit() (* (a) TODO: implement Up reconstruction — Recon(x) = Filt(x) + Recon(b) *)

let rec reconstruct_average_aux (cur: list byte) (prev: list byte) (bpp: nat) (recon: list byte) (i: nat)
  : Tot (option (list byte)) (decreases cur) =
  match cur with
  | [] -> Some (List.rev recon)
  | x :: xs -> admit() (* (a) TODO: implement Average reconstruction — Recon(x) = Filt(x) + floor((Recon(a)+Recon(b))/2) *)

let rec reconstruct_paeth_aux (cur: list byte) (prev: list byte) (bpp: nat) (recon: list byte) (i: nat)
  : Tot (option (list byte)) (decreases cur) =
  match cur with
  | [] -> Some (List.rev recon)
  | x :: xs -> admit() (* (a) TODO: implement Paeth reconstruction — Recon(x) = Filt(x) + PaethPredictor(Recon(a),Recon(b),Recon(c)) *)

let reconstruct_scanline (f: filter_type) (cur: list byte) (prev: list byte) (bpp: nat)
  : option (list byte) =
  match cur with
  | [] -> None
  | fb :: filtered ->
    if fb = filter_byte f then
      match f with
      | FilterNone ->
        (* FilterNone: identity — filtered bytes are the original bytes *)
        Some filtered
      | FilterSub ->
        (* (a) TODO: implement Sub reconstruction — Recon(x) = Filt(x) + Recon(a) *)
        reconstruct_sub_aux filtered prev bpp [] 0
      | FilterUp ->
        (* (a) TODO: implement Up reconstruction — Recon(x) = Filt(x) + Recon(b) *)
        reconstruct_up_aux filtered prev bpp [] 0
      | FilterAverage ->
        (* (a) TODO: implement Average reconstruction — Recon(x) = Filt(x) + floor((Recon(a)+Recon(b))/2) *)
        reconstruct_average_aux filtered prev bpp [] 0
      | FilterPaeth ->
        (* (a) TODO: implement Paeth reconstruction — Recon(x) = Filt(x) + PaethPredictor(Recon(a),Recon(b),Recon(c)) *)
        reconstruct_paeth_aux filtered prev bpp [] 0
    else
      None

(* ========================================================================
   SECTION 5: Roundtrip Lemmas
   ======================================================================== *)

(* FilterNone roundtrip: fully proven *)
let lemma_filter_roundtrip (f: filter_type) (cur prev: list byte) (bpp: nat)
  : Lemma
    (requires length cur = length prev /\ bpp > 0)
    (ensures reconstruct_scanline f (filter_scanline f cur prev bpp) prev bpp == Some cur) =
  match f with
  | FilterNone ->
    (* filter_scanline FilterNone cur prev bpp = 0x00uy :: cur *)
    (* reconstruct_scanline FilterNone (0x00uy :: cur) prev bpp *)
    (* = match (0x00uy :: cur) with [] -> None | fb :: filtered -> *)
    (*   if fb = filter_byte FilterNone (0x00uy) then Some filtered (which is cur) else None *)
    (* = Some cur *)
    ()
  | FilterSub ->
    (* (a) TODO: prove Sub roundtrip lemma *)
    admit()
  | FilterUp ->
    (* (a) TODO: prove Up roundtrip lemma *)
    admit()
  | FilterAverage ->
    (* (a) TODO: prove Average roundtrip lemma *)
    admit()
  | FilterPaeth ->
    (* (a) TODO: prove Paeth roundtrip lemma *)
    admit()
