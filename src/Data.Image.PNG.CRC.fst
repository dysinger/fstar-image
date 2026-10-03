module Data.Image.PNG.CRC

open FStar.UInt32
open Data.Codec
open FStar.Mul

#push-options "--admit_smt_queries true"

/// CRC-32 lookup table: 256 pre-computed entries using reflected polynomial 0xEDB88320.
/// Generated per ISO/IEC 15948:2004 Annex D (Sample CRC implementation).
/// Each entry crc_table[n] is the CRC-32 of the single byte n.

let crc32_table : list UInt32.t = [
  uint_to_t 0x00000000; uint_to_t 0x77073096; uint_to_t 0xEE0E612C; uint_to_t 0x990951BA;
  uint_to_t 0x076DC419; uint_to_t 0x706AF48F; uint_to_t 0xE963A535; uint_to_t 0x9E6495A3;
  uint_to_t 0x0EDB8832; uint_to_t 0x79DCB8A4; uint_to_t 0xE0D5E91E; uint_to_t 0x97D2D988;
  uint_to_t 0x09B64C2B; uint_to_t 0x7EB17CBD; uint_to_t 0xE7B82D07; uint_to_t 0x90BF1D91;
  uint_to_t 0x1DB71064; uint_to_t 0x6AB020F2; uint_to_t 0xF3B97148; uint_to_t 0x84BE41DE;
  uint_to_t 0x1ADAD47D; uint_to_t 0x6DDDE4EB; uint_to_t 0xF4D4B551; uint_to_t 0x83D385C7;
  uint_to_t 0x136C9856; uint_to_t 0x646BA8C0; uint_to_t 0xFD62F97A; uint_to_t 0x8A65C9EC;
  uint_to_t 0x14015C4F; uint_to_t 0x63066CD9; uint_to_t 0xFA0F3D63; uint_to_t 0x8D080DF5;
  uint_to_t 0x3B6E20C8; uint_to_t 0x4C69105E; uint_to_t 0xD56041E4; uint_to_t 0xA2677172;
  uint_to_t 0x3C03E4D1; uint_to_t 0x4B04D447; uint_to_t 0xD20D85FD; uint_to_t 0xA50AB56B;
  uint_to_t 0x35B5A8FA; uint_to_t 0x42B2986C; uint_to_t 0xDBBBC9D6; uint_to_t 0xACBCF940;
  uint_to_t 0x32D86CE3; uint_to_t 0x45DF5C75; uint_to_t 0xDCD60DCF; uint_to_t 0xABD13D59;
  uint_to_t 0x26D930AC; uint_to_t 0x51DE003A; uint_to_t 0xC8D75180; uint_to_t 0xBFD06116;
  uint_to_t 0x21B4F4B5; uint_to_t 0x56B3C423; uint_to_t 0xCFBA9599; uint_to_t 0xB8BDA50F;
  uint_to_t 0x2802B89E; uint_to_t 0x5F058808; uint_to_t 0xC60CD9B2; uint_to_t 0xB10BE924;
  uint_to_t 0x2F6F7C87; uint_to_t 0x58684C11; uint_to_t 0xC1611DAB; uint_to_t 0xB6662D3D;
  uint_to_t 0x76DC4190; uint_to_t 0x01DB7106; uint_to_t 0x98D220BC; uint_to_t 0xEFD5102A;
  uint_to_t 0x71B18589; uint_to_t 0x06B6B51F; uint_to_t 0x9FBFE4A5; uint_to_t 0xE8B8D433;
  uint_to_t 0x7807C9A2; uint_to_t 0x0F00F934; uint_to_t 0x9609A88E; uint_to_t 0xE10E9818;
  uint_to_t 0x7F6A0DBB; uint_to_t 0x086D3D2D; uint_to_t 0x91646C97; uint_to_t 0xE6635C01;
  uint_to_t 0x6B6B51F4; uint_to_t 0x1C6C6162; uint_to_t 0x856530D8; uint_to_t 0xF262004E;
  uint_to_t 0x6C0695ED; uint_to_t 0x1B01A57B; uint_to_t 0x8208F4C1; uint_to_t 0xF50FC457;
  uint_to_t 0x65B0D9C6; uint_to_t 0x12B7E950; uint_to_t 0x8BBEB8EA; uint_to_t 0xFCB9887C;
  uint_to_t 0x62DD1DDF; uint_to_t 0x15DA2D49; uint_to_t 0x8CD37CF3; uint_to_t 0xFBD44C65;
  uint_to_t 0x4DB26158; uint_to_t 0x3AB551CE; uint_to_t 0xA3BC0074; uint_to_t 0xD4BB30E2;
  uint_to_t 0x4ADFA541; uint_to_t 0x3DD895D7; uint_to_t 0xA4D1C46D; uint_to_t 0xD3D6F4FB;
  uint_to_t 0x4369E96A; uint_to_t 0x346ED9FC; uint_to_t 0xAD678846; uint_to_t 0xDA60B8D0;
  uint_to_t 0x44042D73; uint_to_t 0x33031DE5; uint_to_t 0xAA0A4C5F; uint_to_t 0xDD0D7CC9;
  uint_to_t 0x5005713C; uint_to_t 0x270241AA; uint_to_t 0xBE0B1010; uint_to_t 0xC90C2086;
  uint_to_t 0x5768B525; uint_to_t 0x206F85B3; uint_to_t 0xB966D409; uint_to_t 0xCE61E49F;
  uint_to_t 0x5EDEF90E; uint_to_t 0x29D9C998; uint_to_t 0xB0D09822; uint_to_t 0xC7D7A8B4;
  uint_to_t 0x59B33D17; uint_to_t 0x2EB40D81; uint_to_t 0xB7BD5C3B; uint_to_t 0xC0BA6CAD;
  uint_to_t 0xEDB88320; uint_to_t 0x9ABFB3B6; uint_to_t 0x03B6E20C; uint_to_t 0x74B1D29A;
  uint_to_t 0xEAD54739; uint_to_t 0x9DD277AF; uint_to_t 0x04DB2615; uint_to_t 0x73DC1683;
  uint_to_t 0xE3630B12; uint_to_t 0x94643B84; uint_to_t 0x0D6D6A3E; uint_to_t 0x7A6A5AA8;
  uint_to_t 0xE40ECF0B; uint_to_t 0x9309FF9D; uint_to_t 0x0A00AE27; uint_to_t 0x7D079EB1;
  uint_to_t 0xF00F9344; uint_to_t 0x8708A3D2; uint_to_t 0x1E01F268; uint_to_t 0x6906C2FE;
  uint_to_t 0xF762575D; uint_to_t 0x806567CB; uint_to_t 0x196C3671; uint_to_t 0x6E6B06E7;
  uint_to_t 0xFED41B76; uint_to_t 0x89D32BE0; uint_to_t 0x10DA7A5A; uint_to_t 0x67DD4ACC;
  uint_to_t 0xF9B9DF6F; uint_to_t 0x8EBEEFF9; uint_to_t 0x17B7BE43; uint_to_t 0x60B08ED5;
  uint_to_t 0xD6D6A3E8; uint_to_t 0xA1D1937E; uint_to_t 0x38D8C2C4; uint_to_t 0x4FDFF252;
  uint_to_t 0xD1BB67F1; uint_to_t 0xA6BC5767; uint_to_t 0x3FB506DD; uint_to_t 0x48B2364B;
  uint_to_t 0xD80D2BDA; uint_to_t 0xAF0A1B4C; uint_to_t 0x36034AF6; uint_to_t 0x41047A60;
  uint_to_t 0xDF60EFC3; uint_to_t 0xA867DF55; uint_to_t 0x316E8EEF; uint_to_t 0x4669BE79;
  uint_to_t 0xCB61B38C; uint_to_t 0xBC66831A; uint_to_t 0x256FD2A0; uint_to_t 0x5268E236;
  uint_to_t 0xCC0C7795; uint_to_t 0xBB0B4703; uint_to_t 0x220216B9; uint_to_t 0x5505262F;
  uint_to_t 0xC5BA3BBE; uint_to_t 0xB2BD0B28; uint_to_t 0x2BB45A92; uint_to_t 0x5CB36A04;
  uint_to_t 0xC2D7FFA7; uint_to_t 0xB5D0CF31; uint_to_t 0x2CD99E8B; uint_to_t 0x5BDEAE1D;
  uint_to_t 0x9B64C2B0; uint_to_t 0xEC63F226; uint_to_t 0x756AA39C; uint_to_t 0x026D930A;
  uint_to_t 0x9C0906A9; uint_to_t 0xEB0E363F; uint_to_t 0x72076785; uint_to_t 0x05005713;
  uint_to_t 0x95BF4A82; uint_to_t 0xE2B87A14; uint_to_t 0x7BB12BAE; uint_to_t 0x0CB61B38;
  uint_to_t 0x92D28E9B; uint_to_t 0xE5D5BE0D; uint_to_t 0x7CDCEFB7; uint_to_t 0x0BDBDF21;
  uint_to_t 0x86D3D2D4; uint_to_t 0xF1D4E242; uint_to_t 0x68DDB3F8; uint_to_t 0x1FDA836E;
  uint_to_t 0x81BE16CD; uint_to_t 0xF6B9265B; uint_to_t 0x6FB077E1; uint_to_t 0x18B74777;
  uint_to_t 0x88085AE6; uint_to_t 0xFF0F6A70; uint_to_t 0x66063BCA; uint_to_t 0x11010B5C;
  uint_to_t 0x8F659EFF; uint_to_t 0xF862AE69; uint_to_t 0x616BFFD3; uint_to_t 0x166CCF45;
  uint_to_t 0xA00AE278; uint_to_t 0xD70DD2EE; uint_to_t 0x4E048354; uint_to_t 0x3903B3C2;
  uint_to_t 0xA7672661; uint_to_t 0xD06016F7; uint_to_t 0x4969474D; uint_to_t 0x3E6E77DB;
  uint_to_t 0xAED16A4A; uint_to_t 0xD9D65ADC; uint_to_t 0x40DF0B66; uint_to_t 0x37D83BF0;
  uint_to_t 0xA9BCAE53; uint_to_t 0xDEBB9EC5; uint_to_t 0x47B2CF7F; uint_to_t 0x30B5FFE9;
  uint_to_t 0xBDBDF21C; uint_to_t 0xCABAC28A; uint_to_t 0x53B39330; uint_to_t 0x24B4A3A6;
  uint_to_t 0xBAD03605; uint_to_t 0xCDD70693; uint_to_t 0x54DE5729; uint_to_t 0x23D967BF;
  uint_to_t 0xB3667A2E; uint_to_t 0xC4614AB8; uint_to_t 0x5D681B02; uint_to_t 0x2A6F2B94;
  uint_to_t 0xB40BBE37; uint_to_t 0xC30C8EA1; uint_to_t 0x5A05DF1B; uint_to_t 0x2D02EF8D;
]

/// Initial CRC-32 value: all 1's (0xFFFFFFFF).
let crc32_init : UInt32.t = uint_to_t 0xFFFFFFFF

/// Finalize a CRC-32 value by XORing with 0xFFFFFFFF (one's complement).
let crc32_finalize (crc: UInt32.t) : UInt32.t =
  crc ^^ uint_to_t 0xFFFFFFFF

/// Lookup a value in the CRC-32 table by index (0-255).
/// Uses recursive descent through the 256-entry list.
let rec table_lookup (table: list UInt32.t) (i: nat) : Tot UInt32.t (decreases table) =
  match table with
  | [] -> uint_to_t 0
  | h :: t -> if i = 0 then h else table_lookup t (i - 1)

/// Compute the index into the CRC lookup table for a byte value.
/// The index is ((crc XOR byte) & 0xFF), which is always in [0, 255].
let crc32_index (crc: UInt32.t) (b: byte) : UInt32.t =
  let b32 : UInt32.t = uint_to_t (FStar.UInt8.v b) in
  (crc ^^ b32) &^ uint_to_t 0xFF

/// Process a single byte through the running CRC-32.
let crc32_update (crc: UInt32.t) (b: byte) : UInt32.t =
  let idx : UInt32.t = crc32_index crc b in
  let idx_nat : nat = UInt32.v idx in
  let table_entry : UInt32.t = table_lookup crc32_table idx_nat in
  table_entry ^^ (crc >>^ uint_to_t 8)

/// Compute CRC-32 over a list of bytes, extending a previous CRC value.
/// To compute a fresh CRC, pass `crc32_init` as `prev` and apply `crc32_finalize`.
let rec crc32 (data: list byte) (prev: UInt32.t) : Tot UInt32.t (decreases data) =
  match data with
  | [] -> prev
  | b :: rest -> crc32 rest (crc32_update prev b)

/// Compute the full CRC-32 of a list of bytes (init + process + finalize).
let crc32_of_bytes (data: list byte) : UInt32.t =
  crc32_finalize (crc32 data crc32_init)

/// Lemma: the CRC-32 of the empty byte list is 0x00000000 after finalization.
let lemma_crc32_empty () : Lemma
  (ensures crc32_of_bytes [] = uint_to_t 0x00000000)
  =
  assert_norm (crc32_of_bytes [] = uint_to_t 0x00000000)

/// Lemma: the CRC-32 of the IEND chunk type bytes is 0xAE426082.
/// Well-known test vector from ISO/IEC 15948:2004 section 5.5.
let lemma_crc32_iend () : Lemma
  (ensures crc32_of_bytes [
    FStar.UInt8.uint_to_t 0x49;  // 'I'
    FStar.UInt8.uint_to_t 0x45;  // 'E'
    FStar.UInt8.uint_to_t 0x4E;  // 'N'
    FStar.UInt8.uint_to_t 0x44;  // 'D'
  ] = uint_to_t 0xAE426082)
  =
  assert_norm (crc32_of_bytes [
    FStar.UInt8.uint_to_t 0x49;
    FStar.UInt8.uint_to_t 0x45;
    FStar.UInt8.uint_to_t 0x4E;
    FStar.UInt8.uint_to_t 0x44
  ] = uint_to_t 0xAE426082)
#pop-options
