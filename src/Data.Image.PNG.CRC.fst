(*
   Data.Image.PNG.CRC — CRC-32 (ISO/IEC 15948:2004)
   Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later

   CRC-32 over the reflected polynomial 0xEDB88320, computed TABLE-FREE
   (bitwise shift-and-XOR) so the known-answer lemmas are SMT-provable rather
   than admitted via a 256-entry lookup table.
*)
module Data.Image.PNG.CRC

open FStar.UInt32
open FStar.List.Tot
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
   Independent table-driven reference model
   ======================================================================== *)

/// The canonical 256-entry reflected CRC-32 table (poly 0xEDB88320), the
/// STANDARD published table (independent of [crc_step] — these are the
/// well-known constants, not recomputed from the bit-shift fold).  This is
/// the reference against which the table-free [crc32_of_bytes] is checked.
let crc32_table : list UInt32.t =
  [
  0x00000000ul; 0x77073096ul; 0xEE0E612Cul; 0x990951BAul; 0x076DC419ul; 0x706AF48Ful; 0xE963A535ul; 0x9E6495A3ul;
  0x0EDB8832ul; 0x79DCB8A4ul; 0xE0D5E91Eul; 0x97D2D988ul; 0x09B64C2Bul; 0x7EB17CBDul; 0xE7B82D07ul; 0x90BF1D91ul;
  0x1DB71064ul; 0x6AB020F2ul; 0xF3B97148ul; 0x84BE41DEul; 0x1ADAD47Dul; 0x6DDDE4EBul; 0xF4D4B551ul; 0x83D385C7ul;
  0x136C9856ul; 0x646BA8C0ul; 0xFD62F97Aul; 0x8A65C9ECul; 0x14015C4Ful; 0x63066CD9ul; 0xFA0F3D63ul; 0x8D080DF5ul;
  0x3B6E20C8ul; 0x4C69105Eul; 0xD56041E4ul; 0xA2677172ul; 0x3C03E4D1ul; 0x4B04D447ul; 0xD20D85FDul; 0xA50AB56Bul;
  0x35B5A8FAul; 0x42B2986Cul; 0xDBBBC9D6ul; 0xACBCF940ul; 0x32D86CE3ul; 0x45DF5C75ul; 0xDCD60DCFul; 0xABD13D59ul;
  0x26D930ACul; 0x51DE003Aul; 0xC8D75180ul; 0xBFD06116ul; 0x21B4F4B5ul; 0x56B3C423ul; 0xCFBA9599ul; 0xB8BDA50Ful;
  0x2802B89Eul; 0x5F058808ul; 0xC60CD9B2ul; 0xB10BE924ul; 0x2F6F7C87ul; 0x58684C11ul; 0xC1611DABul; 0xB6662D3Dul;
  0x76DC4190ul; 0x01DB7106ul; 0x98D220BCul; 0xEFD5102Aul; 0x71B18589ul; 0x06B6B51Ful; 0x9FBFE4A5ul; 0xE8B8D433ul;
  0x7807C9A2ul; 0x0F00F934ul; 0x9609A88Eul; 0xE10E9818ul; 0x7F6A0DBBul; 0x086D3D2Dul; 0x91646C97ul; 0xE6635C01ul;
  0x6B6B51F4ul; 0x1C6C6162ul; 0x856530D8ul; 0xF262004Eul; 0x6C0695EDul; 0x1B01A57Bul; 0x8208F4C1ul; 0xF50FC457ul;
  0x65B0D9C6ul; 0x12B7E950ul; 0x8BBEB8EAul; 0xFCB9887Cul; 0x62DD1DDFul; 0x15DA2D49ul; 0x8CD37CF3ul; 0xFBD44C65ul;
  0x4DB26158ul; 0x3AB551CEul; 0xA3BC0074ul; 0xD4BB30E2ul; 0x4ADFA541ul; 0x3DD895D7ul; 0xA4D1C46Dul; 0xD3D6F4FBul;
  0x4369E96Aul; 0x346ED9FCul; 0xAD678846ul; 0xDA60B8D0ul; 0x44042D73ul; 0x33031DE5ul; 0xAA0A4C5Ful; 0xDD0D7CC9ul;
  0x5005713Cul; 0x270241AAul; 0xBE0B1010ul; 0xC90C2086ul; 0x5768B525ul; 0x206F85B3ul; 0xB966D409ul; 0xCE61E49Ful;
  0x5EDEF90Eul; 0x29D9C998ul; 0xB0D09822ul; 0xC7D7A8B4ul; 0x59B33D17ul; 0x2EB40D81ul; 0xB7BD5C3Bul; 0xC0BA6CADul;
  0xEDB88320ul; 0x9ABFB3B6ul; 0x03B6E20Cul; 0x74B1D29Aul; 0xEAD54739ul; 0x9DD277AFul; 0x04DB2615ul; 0x73DC1683ul;
  0xE3630B12ul; 0x94643B84ul; 0x0D6D6A3Eul; 0x7A6A5AA8ul; 0xE40ECF0Bul; 0x9309FF9Dul; 0x0A00AE27ul; 0x7D079EB1ul;
  0xF00F9344ul; 0x8708A3D2ul; 0x1E01F268ul; 0x6906C2FEul; 0xF762575Dul; 0x806567CBul; 0x196C3671ul; 0x6E6B06E7ul;
  0xFED41B76ul; 0x89D32BE0ul; 0x10DA7A5Aul; 0x67DD4ACCul; 0xF9B9DF6Ful; 0x8EBEEFF9ul; 0x17B7BE43ul; 0x60B08ED5ul;
  0xD6D6A3E8ul; 0xA1D1937Eul; 0x38D8C2C4ul; 0x4FDFF252ul; 0xD1BB67F1ul; 0xA6BC5767ul; 0x3FB506DDul; 0x48B2364Bul;
  0xD80D2BDAul; 0xAF0A1B4Cul; 0x36034AF6ul; 0x41047A60ul; 0xDF60EFC3ul; 0xA867DF55ul; 0x316E8EEFul; 0x4669BE79ul;
  0xCB61B38Cul; 0xBC66831Aul; 0x256FD2A0ul; 0x5268E236ul; 0xCC0C7795ul; 0xBB0B4703ul; 0x220216B9ul; 0x5505262Ful;
  0xC5BA3BBEul; 0xB2BD0B28ul; 0x2BB45A92ul; 0x5CB36A04ul; 0xC2D7FFA7ul; 0xB5D0CF31ul; 0x2CD99E8Bul; 0x5BDEAE1Dul;
  0x9B64C2B0ul; 0xEC63F226ul; 0x756AA39Cul; 0x026D930Aul; 0x9C0906A9ul; 0xEB0E363Ful; 0x72076785ul; 0x05005713ul;
  0x95BF4A82ul; 0xE2B87A14ul; 0x7BB12BAEul; 0x0CB61B38ul; 0x92D28E9Bul; 0xE5D5BE0Dul; 0x7CDCEFB7ul; 0x0BDBDF21ul;
  0x86D3D2D4ul; 0xF1D4E242ul; 0x68DDB3F8ul; 0x1FDA836Eul; 0x81BE16CDul; 0xF6B9265Bul; 0x6FB077E1ul; 0x18B74777ul;
  0x88085AE6ul; 0xFF0F6A70ul; 0x66063BCAul; 0x11010B5Cul; 0x8F659EFFul; 0xF862AE69ul; 0x616BFFD3ul; 0x166CCF45ul;
  0xA00AE278ul; 0xD70DD2EEul; 0x4E048354ul; 0x3903B3C2ul; 0xA7672661ul; 0xD06016F7ul; 0x4969474Dul; 0x3E6E77DBul;
  0xAED16A4Aul; 0xD9D65ADCul; 0x40DF0B66ul; 0x37D83BF0ul; 0xA9BCAE53ul; 0xDEBB9EC5ul; 0x47B2CF7Ful; 0x30B5FFE9ul;
  0xBDBDF21Cul; 0xCABAC28Aul; 0x53B39330ul; 0x24B4A3A6ul; 0xBAD03605ul; 0xCDD70693ul; 0x54DE5729ul; 0x23D967BFul;
  0xB3667A2Eul; 0xC4614AB8ul; 0x5D681B02ul; 0x2A6F2B94ul; 0xB40BBE37ul; 0xC30C8EA1ul; 0x5A05DF1Bul; 0x2D02EF8Dul
  ]

/// Table lookup (safe: out of range returns 0, though the table always has 256
/// entries and the index is always a byte mask in 0..255).
let crc32_table_lookup (i: UInt32.t) : UInt32.t =
  match List.Tot.nth crc32_table (v (i &^ uint_to_t 0xFF)) with
  | Some v -> v
  | None -> 0x00000000ul

/// One table-driven byte update: crc' = (crc >> 8) XOR table[(crc XOR b) & 0xFF]
/// (the standard reflected CRC-32 recurrence).
let crc32_ref_update (crc: UInt32.t) (b: byte) : UInt32.t =
  let b32 : UInt32.t = uint_to_t (U8.v b) in
  (crc >>^ uint_to_t 8) ^^ crc32_table_lookup (crc ^^ b32)

/// Table-driven CRC-32 reference model (init + fold + finalize).
let rec crc32_ref (data: list byte) (prev: UInt32.t) : Tot UInt32.t (decreases data) =
  match data with
  | [] -> prev
  | b :: rest -> crc32_ref rest (crc32_ref_update prev b)

let crc32_ref_of_bytes (data: list byte) : UInt32.t =
  crc32_finalize (crc32_ref data crc32_init)

/// The table length is exactly 256.
let lemma_crc32_table_length () : Lemma (length crc32_table = 256)
  = assert_norm (length crc32_table = 256)

/// The table-driven reference model agrees with the canonical CRC-32 check
/// value for "123456789" — an INDEPENDENT cross-model check: both the
/// table-free [crc32_of_bytes] and the table-driven [crc32_ref_of_bytes]
/// produce the same published 0xCBF43926.
let lemma_crc32_ref_check_value () : Lemma
  (ensures crc32_ref_of_bytes
      [0x31uy; 0x32uy; 0x33uy; 0x34uy; 0x35uy; 0x36uy; 0x37uy; 0x38uy; 0x39uy]
      == uint_to_t 0xCBF43926)
  = assert_norm (crc32_ref_of_bytes
      [0x31uy; 0x32uy; 0x33uy; 0x34uy; 0x35uy; 0x36uy; 0x37uy; 0x38uy; 0x39uy]
      == uint_to_t 0xCBF43926)

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

/// The two models agree on the canonical check value (cross-model equality on
/// the independent spec constant).
let lemma_crc32_models_agree_check () : Lemma
  (ensures crc32_of_bytes
      [0x31uy; 0x32uy; 0x33uy; 0x34uy; 0x35uy; 0x36uy; 0x37uy; 0x38uy; 0x39uy]
      == crc32_ref_of_bytes
      [0x31uy; 0x32uy; 0x33uy; 0x34uy; 0x35uy; 0x36uy; 0x37uy; 0x38uy; 0x39uy])
  = lemma_crc32_check_value ();
    lemma_crc32_ref_check_value ()
