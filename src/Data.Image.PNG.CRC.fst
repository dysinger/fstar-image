(*
   Data.Image.PNG.CRC — CRC-32 (ISO/IEC 15948:2004)
   Copyright 2026 Department of Code LLC. All rights reserved.

   CRC-32 over the reflected polynomial 0xEDB88320, computed TABLE-FREE
   (bitwise shift-and-XOR) so the known-answer lemmas are SMT-provable rather
   than admitted via a 256-entry lookup table.
*)
module Data.Image.PNG.CRC

open FStar.UInt32
open Data.Codec
module U8 = FStar.UInt8

/// The reflected CRC-32 polynomial (ISO/IEC 15948 Annex D).
let crc_poly : UInt32.t = uint_to_t 0xEDB88320

/// Initial CRC-32 value: all 1's (0xFFFFFFFF).
let crc32_init : UInt32.t = uint_to_t 0xFFFFFFFF

/// Finalize a CRC-32 value by XORing with 0xFFFFFFFF (one's complement).
let crc32_finalize (crc: UInt32.t) : UInt32.t =
  crc ^^ uint_to_t 0xFFFFFFFF

/// One reflected bit step: if the LSB is set, shift right and XOR the
/// polynomial; otherwise just shift right.
let crc_step (c: UInt32.t) : UInt32.t =
  if (c &^ uint_to_t 1) = uint_to_t 0
  then c >>^ uint_to_t 1
  else (c >>^ uint_to_t 1) ^^ crc_poly

/// Fold 8 bit steps (one input byte's worth of reflection).
let rec crc_byte_fold (c: UInt32.t) (n: nat) : Tot UInt32.t (decreases n) =
  if n = 0 then c else crc_byte_fold (crc_step c) (n - 1)

/// Process a single byte through the running CRC-32 (table-free).
let crc32_update (crc: UInt32.t) (b: byte) : UInt32.t =
  let b32 : UInt32.t = uint_to_t (U8.v b) in
  crc_byte_fold (crc ^^ b32) 8

/// Compute CRC-32 over a list of bytes, extending a previous CRC value.
let rec crc32 (data: list byte) (prev: UInt32.t) : Tot UInt32.t (decreases data) =
  match data with
  | [] -> prev
  | b :: rest -> crc32 rest (crc32_update prev b)

/// Compute the full CRC-32 of a list of bytes (init + process + finalize).
let crc32_of_bytes (data: list byte) : UInt32.t =
  crc32_finalize (crc32 data crc32_init)

(* ========================================================================
   Known-Answer Lemmas
   ======================================================================== *)

/// The CRC-32 of the empty byte list is 0x00000000 after finalization.
let lemma_crc32_empty () : Lemma
  (ensures crc32_of_bytes [] == uint_to_t 0x00000000)
  = assert_norm (crc32_of_bytes [] == uint_to_t 0x00000000)

/// The CRC-32 of "123456789" is 0xCBF43926 (the canonical CRC-32 check value,
/// also used by zlib's test suite for Adler/CRC generators).
let lemma_crc32_check_value () : Lemma
  (ensures crc32_of_bytes [
     0x31uy; 0x32uy; 0x33uy; 0x34uy; 0x35uy; 0x36uy; 0x37uy; 0x38uy; 0x39uy
   ] == uint_to_t 0xCBF43926)
  = assert_norm (crc32_of_bytes [
      0x31uy; 0x32uy; 0x33uy; 0x34uy; 0x35uy; 0x36uy; 0x37uy; 0x38uy; 0x39uy
   ] == uint_to_t 0xCBF43926)

/// The CRC-32 of the IEND chunk type bytes ("IEND") is 0xAE426082
/// (ISO/IEC 15948:2004 §5.5).
let lemma_crc32_iend () : Lemma
  (ensures crc32_of_bytes [0x49uy; 0x45uy; 0x4Euy; 0x44uy] == uint_to_t 0xAE426082)
  = assert_norm (crc32_of_bytes [0x49uy; 0x45uy; 0x4Euy; 0x44uy] == uint_to_t 0xAE426082)
