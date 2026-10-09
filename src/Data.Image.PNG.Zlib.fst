(*
   Data.Image.PNG.Zlib — Zlib Wrapper (RFC 1950)
   Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later

   v0.1: CMF=0x78, FLG=0x9C. Only stored blocks (BTYPE=00).
*)
module Data.Image.PNG.Zlib
open Data.Codec
open FStar.List.Tot
open Data.Image.PNG.Deflate

(* ---- Adler-32 ---- *)

let rec adler32_loop (s1: nat) (s2: nat) (data: list byte) : Tot nat (decreases data) =
  match data with
  | [] -> s2 * 65536 + s1
  | b :: rest ->
    let bval = FStar.UInt8.v b in
    let s1' = (s1 + bval) % 65521 in
    let s2' = (s2 + s1') % 65521 in
    adler32_loop s1' s2' rest

let adler32 (data: list byte) : nat = adler32_loop 1 0 data

(* ---- 4-byte big-endian ---- *)

let nat_to_bytes_be4 (n: nat) : list byte =
  [FStar.UInt8.uint_to_t ((n / 16777216) % 256);
   FStar.UInt8.uint_to_t ((n / 65536) % 256);
   FStar.UInt8.uint_to_t ((n / 256) % 256);
   FStar.UInt8.uint_to_t (n % 256)]

let parse_u32_be (bs: list byte) : option (nat & list byte) =
  match bs with
  | b0 :: b1 :: b2 :: b3 :: rest ->
    Some (FStar.UInt8.v b0 * 16777216 +
          FStar.UInt8.v b1 * 65536 +
          FStar.UInt8.v b2 * 256 +
          FStar.UInt8.v b3, rest)
  | _ -> None

(* ---- Zlib wrap ---- *)

let zlib_wrap (data: list byte {length data < 65536}) : list byte =
  let cmf : byte = 0x78uy in
  let flg : byte = 0x9Cuy in
  [cmf; flg] @ deflate_stored_block data true @ nat_to_bytes_be4 (adler32 data)

(* ---- Zlib unwrap ---- *)

/// Validate the CMF and FLG bytes. Returns None if invalid.
let validate_zlib_header (cmf: byte) (flg: byte) : option unit =
  let cmf_val = FStar.UInt8.v cmf in
  let flg_val = FStar.UInt8.v flg in
  if cmf_val % 16 <> 8 then None
  else if cmf_val / 16 > 7 then None
  else if (cmf_val * 256 + flg_val) % 31 <> 0 then None
  else if (flg_val / 32) % 2 <> 0 then None
  else Some ()

/// Parse zlib-wrapped data. Returns Some (data, remaining) or None on error.
let zlib_unwrap (bytes: list byte) : option (list byte & list byte) =
  match bytes with
  | cmf :: flg :: rest ->
    (match validate_zlib_header cmf flg with
     | None -> None
     | Some () ->
       match parse_stored_block rest with
       | None -> None
       | Some (data, after_deflate) ->
         match parse_u32_be after_deflate with
         | None -> None
         | Some (adler_stored, remaining) ->
           if adler_stored = adler32 data then Some (data, remaining)
           else None)
  | _ -> None

(* ---- Lemma ---- *)

/// The concrete zlib header 0x78 0x9C validates.
let lemma_zlib_header_ok () : Lemma (validate_zlib_header 0x78uy 0x9Cuy == Some ())
  = ()

/// [adler32_loop] keeps both running sums strictly below 65521 (the Adler-32
/// modulus), hence the final value s2*65536 + s1 < 2^32.
let rec lemma_adler32_loop_bound (s1 s2: nat) (data: list byte) : Lemma
  (requires s1 < 65521 /\ s2 < 65521)
  (ensures adler32_loop s1 s2 data < 4294967296)
  (decreases data)
  = match data with
    | [] -> ()
    | b :: rest ->
      let bval = FStar.UInt8.v b in
      lemma_adler32_loop_bound ((s1 + bval) % 65521) ((s2 + ((s1 + bval) % 65521)) % 65521) rest

/// Adler-32 is always < 2^32.
let lemma_adler32_bound (data: list byte) : Lemma (adler32 data < 4294967296)
  = lemma_adler32_loop_bound 1 0 data

/// Adler-32 known-answer: the RFC-1950 / zlib canonical check value for the
/// ASCII bytes of "123456789" is 0x091E01DE (= 152961502).  This is an
/// INDEPENDENT spec constant (not a recomputation of [adler32] itself).
let lemma_adler32_check_value () : Lemma
  (ensures adler32
      [0x31uy; 0x32uy; 0x33uy; 0x34uy; 0x35uy; 0x36uy; 0x37uy; 0x38uy; 0x39uy]
      == 152961502)
  = assert_norm (adler32
      [0x31uy; 0x32uy; 0x33uy; 0x34uy; 0x35uy; 0x36uy; 0x37uy; 0x38uy; 0x39uy]
      == 152961502)

/// FCHECK divisibility: the zlib header (CMF=0x78=120, FLG=0x9C=156) satisfies
/// (CMF*256 + FLG) % 31 == 0, as required by RFC-1950 §2.2 (the 16-bit value
/// must be a multiple of 31).  (120*256 + 156) = 30876 = 31 * 996.
let lemma_zlib_fcheck () : Lemma ((120 * 256 + 156) % 31 == 0)
  = assert_norm ((120 * 256 + 156) % 31 == 0)

/// [nat_to_bytes_be4] / [parse_u32_be] are inverse for n < 2^32.
let lemma_u32_be_roundtrip (n: nat {n < 4294967296}) : Lemma
  (parse_u32_be (nat_to_bytes_be4 n) == Some (n, []))
  = ()

/// [parse_u32_be (nat_to_bytes_be4 n @ s)] == [Some (n, s)].
let lemma_u32_be_roundtrip_suffix (n: nat {n < 4294967296}) (s: list byte) : Lemma
  (parse_u32_be (nat_to_bytes_be4 n @ s) == Some (n, s))
  = ()

/// The zlib wrap/unwrap roundtrip: wrapping then unwrapping recovers the data.
let lemma_zlib_roundtrip (data: list byte {length data < 65536})
  : Lemma (ensures zlib_unwrap (zlib_wrap data) == Some (data, []))
  =
  let adler = adler32 data in
  lemma_zlib_header_ok ();
  lemma_adler32_bound data;
  lemma_u32_be_roundtrip_suffix adler [];
  lemma_stored_roundtrip_suffix data (nat_to_bytes_be4 adler);
  ()
