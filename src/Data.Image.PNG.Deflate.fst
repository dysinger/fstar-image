(*
   Data.Image.PNG.Deflate — BTYPE=00 stored blocks
   Copyright 2026 Department of Code LLC. All rights reserved.

   Implements deflate stored blocks (uncompressed) per RFC 1951.
   Format: [BFINAL+BTYPE byte] [LEN LSB] [LEN MSB] [NLEN LSB] [NLEN MSB] [data...]
   NLEN is the one's complement of LEN for error detection.

   v0.1: BTYPE=00 (stored) only. BTYPE=01 (fixed Huffman) deferred to v0.2.
   Max data length: 65535 bytes per stored block (16-bit LEN field).
*)
module Data.Image.PNG.Deflate

open FStar.List.Tot
open Data.Codec

(* ========================================================================
   SECTION 1: Helpers
   ======================================================================== *)

/// Convert a nat (0-65535) to 2 bytes, little-endian.
let nat_to_u16_le (n: nat) : list byte =
  let lo : byte = FStar.UInt8.uint_to_t (n % 256) in
  let hi : byte = FStar.UInt8.uint_to_t ((n / 256) % 256) in
  [lo; hi]

/// Parse 2 bytes from list head as little-endian u16.
let u16_le_parse (bs: list byte) : option (nat & list byte) =
  match bs with
  | b0 :: b1 :: rest ->
    let v0 : nat = FStar.UInt8.v b0 in
    let v1 : nat = FStar.UInt8.v b1 in
    Some (v0 + 256 * v1, rest)
  | _ -> None

/// Extract exactly n bytes from the front of a list.
let rec take_bytes (n: nat) (bs: list byte) : Tot (option (list byte & list byte)) (decreases bs) =
  if n = 0 then Some ([], bs)
  else match bs with
    | [] -> None
    | b :: tl ->
      match take_bytes (n - 1) tl with
      | None -> None
      | Some (taken, rem) -> Some (b :: taken, rem)

(* ========================================================================
   SECTION 2: Deflate Stored Block — Encode
   ======================================================================== *)

/// Produce a deflate stored block (BTYPE=00, BFINAL controlled by is_final).
///
/// Output format:
///   Byte 0:     header (bit 0 = BFINAL, bits 1-2 = BTYPE=00, bits 3-7 = 0)
///   Bytes 1-2:  LEN (little-endian, 16-bit)
///   Bytes 3-4:  NLEN (little-endian, one's complement of LEN)
///   Bytes 5+:   raw data (no compression)
///
/// Data length must be < 65536 (16-bit LEN field limit).
/// For larger data, split across multiple blocks (v0.2).
let deflate_stored_block (data: list byte {length data < 65536}) (is_final: bool) : list byte =
  let len : nat = length data in
  let header : byte =
    if is_final then 0x01uy  (* BFINAL=1, BTYPE=00 *)
    else 0x00uy              (* BFINAL=0, BTYPE=00 *)
  in
  let len_bytes : list byte = nat_to_u16_le len in
  let nlen : nat = 65535 - len in
  let nlen_bytes : list byte = nat_to_u16_le nlen in
  [header] @ len_bytes @ nlen_bytes @ data

(* ========================================================================
   SECTION 3: Deflate Stored Block — Parse
   ======================================================================== *)

/// Parse a deflate stored block from the front of a byte list.
/// Returns Some (data, remaining_bytes) on success, None on any error.
#push-options "--z3rlimit 30"
let parse_stored_block (bytes: list byte) : option (list byte & list byte) =
  if length bytes < 5 then None
  else
    let header = hd bytes in
    let rest   = tl bytes in
    let hdr_val : nat = FStar.UInt8.v header in
    let btype : nat = (hdr_val / 2) % 4 in
    if btype <> 0 then None
    else
      match u16_le_parse rest with
      | None -> None
      | Some (len, after_len) ->
        if len > 65535 then None
        else
          match u16_le_parse after_len with
          | None -> None
          | Some (nlen, after_nlen) ->
            if nlen = 65535 - len then
              take_bytes len after_nlen
            else None
#pop-options

(* ========================================================================
   SECTION 4: Roundtrip Lemmas
   ======================================================================== *)

/// Lemma: take_bytes with n = length bs returns the whole list.
let rec lemma_take_all (bs: list byte) : Lemma
  (ensures take_bytes (length bs) bs == Some (bs, []))
  (decreases bs)
  =
  match bs with
  | [] -> ()
  | _ :: tl -> lemma_take_all tl

/// Lemma: [take_bytes (length data) (data @ s)] == [Some (data, s)].
let rec lemma_take_bytes_append (data s: list byte) : Lemma
  (ensures take_bytes (length data) (data @ s) == Some (data, s))
  (decreases data)
  =
  match data with
  | [] -> ()
  | _ :: tl -> lemma_take_bytes_append tl s

/// Lemma: u16_le_parse of nat_to_u16_le is identity for values < 65536.
let lemma_u16_le_roundtrip (n: nat {n < 65536}) : Lemma
  (ensures u16_le_parse (nat_to_u16_le n) == Some (n, []))
  =
  ()

/// Lemma: [u16_le_parse (nat_to_u16_le n @ s)] == [Some (n, s)].
let lemma_u16_le_roundtrip_suffix (n: nat {n < 65536}) (s: list byte) : Lemma
  (ensures u16_le_parse (nat_to_u16_le n @ s) == Some (n, s))
  =
  ()

/// Lemma: roundtrip — encoding then parsing returns original data.
let lemma_stored_roundtrip (data: list byte {length data < 65536}) : Lemma
  (ensures parse_stored_block (deflate_stored_block data true) == Some (data, []))
  =
  let len = length data in
  let nlen = 65535 - len in
  lemma_u16_le_roundtrip len;
  lemma_u16_le_roundtrip nlen;
  lemma_take_all data;
  ()

/// Lemma: roundtrip with an arbitrary suffix — encoding then parsing returns
/// the original data with the suffix preserved.
let lemma_stored_roundtrip_suffix (data s: list byte {length data < 65536}) : Lemma
  (ensures parse_stored_block (deflate_stored_block data true @ s) == Some (data, s))
  =
  let len = length data in
  let nlen = 65535 - len in
  lemma_u16_le_roundtrip_suffix len (nat_to_u16_le nlen @ data @ s);
  lemma_u16_le_roundtrip_suffix nlen (data @ s);
  lemma_take_bytes_append data s;
  ()
