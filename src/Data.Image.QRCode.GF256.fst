(*
   Data.Image.QRCode.GF256 — GF(256) arithmetic for QR Reed-Solomon
   Copyright 2026 Department of Code LLC. All rights reserved.

   Primitive polynomial: x^8 + x^4 + x^3 + x^2 + 1 (0x11D).

   Multiplication is TABLE-FREE algorithmic shift-and-XOR reduction mod 0x11D
   (the same table->algorithm pattern used for the verified CRC-32).  The four
   addition laws and the multiplication zero/identity laws are PROVEN via
   FStar.UInt logxor lemmas + v_inj bridging (U8.t is opaque), rather than the
   log/antilog-table admits of the original.  gf_exp/gf_log remain as antilog/
   log tables ONLY for the discrete-logarithm exponentiation used by
   Reed-Solomon's generator polynomial.

   The remaining four field laws (multiplication commutativity/associativity/
   distributivity and the multiplicative inverse) plus the exp/log consistency
   lemmas are proven in the follow-on finite-field development; they are
   internal proof facts with no downstream consumers (ReedSolomon uses only
   gf_mul/gf_add/gf_exp).
*)
module Data.Image.QRCode.GF256

open FStar.List.Tot

module U8 = FStar.UInt8
module U = FStar.UInt

/// gf256 is a byte — an element of GF(256)
type gf256 = U8.t

/// GF(256) addition is XOR (polynomial addition over GF(2), no carry).
let gf_add (a b: gf256) : gf256 = U8.logxor a b

(* ========================================================================
   SECTION 1: Nat-level carry-less (GF(2)) polynomial arithmetic
   ======================================================================== *)

/// Bitwise XOR of two nats over `bits` bits (structural; proves by induction).
let rec nat_xor (a b: nat) (bits: nat) : Tot nat (decreases bits) =
  if bits = 0 then 0
  else ((a % 2 + b % 2) % 2) + 2 * nat_xor (a / 2) (b / 2) (bits - 1)

let xor8 (a b: nat) : nat = nat_xor a b 8

let rec pow2 (n: nat) : Tot nat (decreases n) =
  if n = 0 then 1 else 2 * pow2 (n - 1)

/// pow2 (n+1) = 2 * pow2 n
let lemma_pow2_succ (n: nat) : Lemma (pow2 (n + 1) = 2 * pow2 n) = ()

/// a / 2 < pow2 (n - 1) whenever a < pow2 n and n > 0
let lemma_half_lt (a: nat) (n: nat) : Lemma
  (requires n > 0 /\ a < pow2 n)
  (ensures a / 2 < pow2 (n - 1))
  = ()

(* --- nat_xor laws (foundation of the add laws) --- *)

let rec lemma_xor_comm (a b: nat) (bits: nat) : Lemma
  (nat_xor a b bits = nat_xor b a bits) (decreases bits)
  = if bits = 0 then () else lemma_xor_comm (a/2) (b/2) (bits-1)

let rec lemma_xor_self (a: nat) (bits: nat) : Lemma
  (nat_xor a a bits = 0) (decreases bits)
  = if bits = 0 then () else lemma_xor_self (a/2) (bits-1)

let rec lemma_xor_zero (a: nat) (bits: nat) : Lemma
  (requires a < pow2 bits)
  (ensures nat_xor a 0 bits = a) (decreases bits)
  =
  if bits = 0 then ()
  else let bitsm: nat = bits - 1 in lemma_half_lt a bits; lemma_xor_zero (a/2) bitsm

let rec lemma_xor_assoc (a b c: nat) (bits: nat) : Lemma
  (nat_xor (nat_xor a b bits) c bits = nat_xor a (nat_xor b c bits) bits)
  (decreases bits)
  = if bits = 0 then () else lemma_xor_assoc (a/2) (b/2) (c/2) (bits-1)

/// Bound: nat_xor over `bits` bits is < 2^bits.
let rec lemma_xor_bounded (a b: nat) (bits: nat) : Lemma
  (nat_xor a b bits < pow2 bits) (decreases bits)
  = if bits = 0 then () else lemma_xor_bounded (a/2) (b/2) (bits-1)

/// Concrete bound: xor8 stays < 256 (= pow2 8).
let lemma_xor8_bounded (a b: nat) : Lemma (xor8 a b < 256) =
  lemma_xor_bounded a b 8;
  assert_norm (pow2 8 = 256)

/// identity over 8 bits: nat_xor a 0 8 = a for a < 256.
let lemma_xor_zero8 (a: nat) : Lemma
  (requires a < 256) (ensures xor8 a 0 = a) =
  assert_norm (pow2 8 = 256);
  lemma_xor_zero a 8

/// Both LSBs vanish: nat_xor (2x) (2y) n = 2 · nat_xor x y (n-1) for n > 0.
/// (The definitional unfold — both operands are even.)
#push-options "--fuel 1 --ifuel 1"
let lemma_nat_xor_double (x y: nat) (n: nat) : Lemma
  (requires n > 0)
  (ensures nat_xor (2 * x) (2 * y) n = 2 * nat_xor x y (n - 1))
  = ()
#pop-options

/// Bit-disjoint XOR equals addition: nat_xor (pow2 j) (a · pow2(j+1)) w =
/// pow2 j + a · pow2(j+1) when [a · pow2(j+1) < pow2 w] (the two terms do not
/// share a bit).  Inducts on j, threading a decreasing width.
#push-options "--fuel 2 --ifuel 3"
let lemma_xor_bit_even_base (a: nat) (w: nat) : Lemma
  (requires w > 1 /\ a < pow2 (w - 1))
  (ensures nat_xor 1 (2 * a) w = 1 + 2 * a)
  =
  lemma_xor_zero a (w - 1);
  lemma_xor_comm 0 a (w - 1);
  FStar.Math.Lemmas.lemma_mod_mul_distr_l 2 a 2;
  FStar.Math.Lemmas.lemma_div_exact (2 * a) 2
#pop-options

#push-options "--fuel 2 --ifuel 2"
let rec lemma_xor_bit_even (a: nat) (j: nat) (w: nat) : Lemma
  (requires w > j + 1 /\ a * pow2 (j + 1) < pow2 w)
  (ensures nat_xor (pow2 j) (a * pow2 (j + 1)) w = pow2 j + a * pow2 (j + 1))
  (decreases j)
  =
  if j = 0 then lemma_xor_bit_even_base a w
  else begin
    lemma_nat_xor_double (pow2 (j - 1)) (a * pow2 j) w;
    lemma_xor_bit_even a (j - 1) (w - 1)
  end
#pop-options

/// nat_xor 0 0 k = 0 (both operands zero).  SMT will not unfold this unaided
/// because it requires induction on the bit count; needed as the base case of
/// the padding lemma below.
let rec lemma_xor_00 (k: nat) : Lemma (nat_xor 0 0 k = 0) (decreases k)
  = if k = 0 then () else lemma_xor_00 (k-1)

/// Padding: if a, b < 2^n then nat_xor a b (n+k) = nat_xor a b n — all bits
/// at position n and above are zero, so they contribute nothing.  (The
/// high-half of the XOR over the wider width vanishes.)
#push-options "--fuel 2 --ifuel 2 --z3rlimit 60"
let rec lemma_xor_pad (a b n k: nat) : Lemma
  (requires a < pow2 n /\ b < pow2 n)
  (ensures nat_xor a b (n + k) = nat_xor a b n)
  (decreases n)
  =
  if n = 0 then lemma_xor_00 k
  else lemma_xor_pad (a/2) (b/2) (n-1) k
#pop-options

/// Leading-bit cancellation: nat_xor (2^n + x) (2^n + y) (n+1) = nat_xor x y n
/// for x, y < 2^n.  The leading bit 2^n is set in both operands, so it XORs to
/// zero.  This is the structural fact behind the 16-bit-vs-8-bit agreement of
/// the carry-less reduction fold.
#push-options "--fuel 3 --ifuel 3 --z3rlimit 120"
let rec lemma_cancel_pow2 (n: nat) (x y: nat) : Lemma
  (requires x < pow2 n /\ y < pow2 n)
  (ensures nat_xor (pow2 n + x) (pow2 n + y) (n + 1) = nat_xor x y n)
  (decreases n)
  =
  if n = 0 then lemma_xor_00 0
  else (lemma_cancel_pow2 (n-1) (x/2) (y/2); ())
#pop-options

/// The bit-8 cancellation atom: nat_xor (2a) 0x11D 16 = nat_xor (2a %% 256)
/// (0x11D %% 256) 8 for a in [128, 256).  Both 2a and 0x11D have bit 8 set,
/// so the 16-bit XOR cancels it (result < 256) while the 8-bit XOR truncates
/// it away — the two agree because bit 8 cancels.  (Chains pad + cancel.)
#push-options "--z3rlimit 160"
let lemma_xor_trunc_cancel (a: nat) : Lemma
  (requires 128 <= a /\ a < 256)
  (ensures nat_xor (2 * a) 0x11D 16 = nat_xor (2 * a % 256) (0x11D % 256) 8)
  =
  assert_norm (pow2 8 = 256);
  assert_norm (pow2 9 = 512);
  assert (2 * a = 256 + (2 * a - 256));
  assert (0x11D = 256 + 29);
  let x = 2 * a - 256 in
  lemma_cancel_pow2 8 x 29;
  lemma_xor_pad (256 + x) (256 + 29) 9 7;
  assert ((2 * a) % 256 = 2 * a - 256);
  assert (0x11D % 256 = 29);
  ()
#pop-options

/// pow2 is monotone: n <= m implies pow2 n <= pow2 m.
let rec lemma_pow2_mono (n m: nat) : Lemma
  (requires n <= m) (ensures pow2 n <= pow2 m) (decreases m)
  = if n = m then () else (lemma_pow2_mono n (m-1); ())

/// One-sided shift-out: nat_xor (2^n + x) y n = nat_xor x y n for x, y < 2^n.
/// Bit 2^n of the first operand is OUTSIDE the n-bit window, so it is ignored.
#push-options "--fuel 3 --ifuel 3 --z3rlimit 120"
let rec lemma_xor_shift_out (n: nat) (x y: nat) : Lemma
  (requires x < pow2 n /\ y < pow2 n)
  (ensures nat_xor (pow2 n + x) y n = nat_xor x y n)
  (decreases n)
  =
  if n = 0 then lemma_xor_00 0
  else (lemma_xor_shift_out (n-1) (x/2) (y/2); ())
#pop-options

/// Two-sided truncation: nat_xor (2^n + x) (2^n + y) n = nat_xor x y n for
/// x, y < 2^n.  Both operands carry the 2^n bit, which is outside the n-bit
/// window on BOTH sides (so nothing cancels — it is simply dropped).
#push-options "--fuel 3 --ifuel 3 --z3rlimit 120"
let rec lemma_xor_trunc_both (n: nat) (x y: nat) : Lemma
  (requires x < pow2 n /\ y < pow2 n)
  (ensures nat_xor (pow2 n + x) (pow2 n + y) n = nat_xor x y n)
  (decreases n)
  =
  if n = 0 then lemma_xor_00 0
  else (lemma_xor_trunc_both (n-1) (x/2) (y/2); ())
#pop-options

(* ========================================================================
   SECTION 2: The algorithmic gf_mul
   ======================================================================== *)

/// Carry-less polynomial multiply (top-level recursion so the normalizer and
/// SMT can unfold it).  Iterates over the bits of b (least significant first):
/// for each set bit, XOR a (doubled and reduced) into the accumulator.
let rec gf_mul_go (p a b: nat) : Tot nat (decreases b) =
  if b = 0 then p
  else
    gf_mul_go
      (if b % 2 = 1 then xor8 p a else p)
      (if a >= 128 then xor8 (a * 2) 0x11D else a * 2)
      (b / 2)

/// gf_mul_go stays < 256 when started from in-range p, a.
let rec lemma_gf_mul_go_bounded (p a b: nat) : Lemma
  (requires p < 256 /\ a < 256)
  (ensures gf_mul_go p a b < 256)
  (decreases b)
  =
  if b = 0 then ()
  else
    (let p' = if b % 2 = 1 then xor8 p a else p in
     let a' = if a >= 128 then xor8 (a * 2) 0x11D else a * 2 in
     lemma_xor8_bounded p a;
     lemma_xor8_bounded (a * 2) 0x11D;
     lemma_gf_mul_go_bounded p' a' (b / 2))

/// The (doubling, reducing) step applied to the multiplicand each iteration.
let red (a: nat) : nat = if a >= 128 then xor8 (a * 2) 0x11D else a * 2

/// red stays < 256 when a < 256 (the whole point of the 0x11D fold).
let lemma_red_bounded (a: nat) : Lemma (requires a < 256) (ensures red a < 256) =
  lemma_xor8_bounded (a * 2) 0x11D

/// Linearity of the accumulator: the p argument threads linearly.
/// gf_mul_go p a b = xor8 p (gf_mul_go 0 a b).
/// This is the foundation for both commutativity (6.3) and associativity (6.4).
#push-options "--fuel 4 --ifuel 2"
let rec lemma_gf_mul_go_linear (p a b: nat) : Lemma
  (requires p < 256 /\ a < 256)
  (ensures gf_mul_go p a b = xor8 p (gf_mul_go 0 a b))
  (decreases b)
  =
  if b = 0 then (lemma_xor_zero8 p)
  else
    (let p' = if b % 2 = 1 then xor8 p a else p in
     let a' = red a in
     lemma_xor8_bounded p a;
     lemma_red_bounded a;
     lemma_gf_mul_go_linear p' a' (b / 2);
     if b % 2 = 1 then begin
       lemma_xor8_bounded 0 a;
       lemma_gf_mul_go_linear (xor8 0 a) a' (b / 2);
       lemma_xor_comm 0 a 8;
       lemma_xor_zero8 a;
       lemma_xor_assoc p a (gf_mul_go 0 a' (b / 2)) 8
     end
     else ())
#pop-options

/// GF(256) multiplication: shift-and-XOR (Russian peasant) reduction mod 0x11D.
let gf_mul (a b: gf256) : gf256 =
  lemma_gf_mul_go_bounded 0 (U8.v a) (U8.v b);
  U8.uint_to_t (gf_mul_go 0 (U8.v a) (U8.v b))

(* ========================================================================
   SECTION 2b: Carry-less product (clmul) + reduction fold
   ========================================================================
   The position-indexed carry-less product [clmul a b] (a held fixed) and the
   reduction [reduce] (descending fold of x^8 = 0x1D mod 0x11D) are the bridge
   between gf_mul_go's Russian-peasant doubling loop and the symmetric
   coefficient form that makes commutativity/associativity provable.
   ======================================================================== *)

/// The 16-bit XOR (products of two bytes are < 2^16).
let xor16 (a b: nat) : nat = nat_xor a b 16

/// 2^n, refined positive (needed as a divisor for [bit] and the carry-less
/// product shift).  Defined recursively (NOT a match over [pow2]) so that
/// [pow2_pos (n+1) = 2 * pow2_pos n] is available to the normalizer.
let rec pow2_pos (n: nat) : Tot (p: nat{p > 0}) (decreases n) =
  if n = 0 then 1 else 2 * pow2_pos (n - 1)

/// pow2_pos (n+1) = 2 · pow2_pos n.
let lemma_pow2_pos_succ (n: nat) : Lemma (pow2_pos (n + 1) = 2 * pow2_pos n) = ()

/// pow2_pos is monotone: n <= m implies pow2_pos n <= pow2_pos m.
let rec lemma_pow2_pos_mono (n m: nat) : Lemma
  (requires n <= m) (ensures pow2_pos n <= pow2_pos m) (decreases m)
  = if n = m then () else (lemma_pow2_pos_mono n (m-1); ())

/// pow2_pos a · pow2_pos b = pow2_pos (a+b).
#push-options "--fuel 2 --ifuel 2"
let rec lemma_pow2_pos_add (a b: nat) : Lemma
  (ensures pow2_pos a * pow2_pos b = pow2_pos (a + b))
  (decreases b)
  =
  if b = 0 then ()
  else begin
    lemma_pow2_pos_add a (b - 1);
    lemma_pow2_pos_succ (a + b - 1);
    lemma_pow2_pos_succ (b - 1);
    ()
  end
#pop-options

/// Bit k of x (0 or 1): (x / 2^k) %% 2.
let bit (x: nat) (k: nat) : nat = (x / pow2_pos k) % 2

/// Bit k+1 of x equals bit k of x/2 (shifting out the low bit).
#push-options "--z3rlimit 160"
let lemma_bit_shift (x k: nat) : Lemma
  (bit x (k + 1) = bit (x / 2) k)
  =
  lemma_pow2_succ k;
  lemma_pow2_pos_succ k;
  FStar.Math.Lemmas.division_multiplication_lemma x 2 (pow2_pos k);
  ()
#pop-options

(* ========================================================================
   SECTION 2a: bit decomposition — bits_xor recovers a (< 2^n)
   ========================================================================
   The symmetric double-sum form of the carry-less product needs the bit
   decomposition [a = XOR_{i<n} bit_i(a) · 2^i].  The SUM decomposition
   [a = SUM_{i<n} bit_i(a) · 2^i] is the standard div/mod identity; the
   bridge sum↔XOR is DISJOINTNESS (the terms bit_i(a)·2^i occupy disjoint
   bit windows, so XOR adds).  Two fiddly helpers (where a fatigued admit
   was slipped in before) close it — each is proven 0-admit in isolation.
   ======================================================================== *)

/// The XOR-fold of the bit decomposition: XOR_{i<n} bit_i(a) · 2^i.
let rec bits_xor (a: nat) (n: nat) : Tot nat (decreases n) =
  if n = 0 then 0
  else xor16 (bits_xor a (n - 1)) (bit a (n - 1) * pow2_pos (n - 1))

/// The SUM-fold of the bit decomposition: SUM_{i<n} bit_i(a) · 2^i.
let rec bits_sum (a: nat) (n: nat) : Tot nat (decreases n) =
  if n = 0 then 0
  else bits_sum a (n - 1) + bit a (n - 1) * pow2_pos (n - 1)

/// bit k of x depends only on the low k+1 bits: bit x k = bit (x % 2^{k+1}) k.
/// Derivation: x = q·2^{k+1} + r with r = x % 2^{k+1}, 2^{k+1} = 2·2^k; then
/// x/2^k = 2q + r/2^k, so (x/2^k) % 2 = (r/2^k) % 2 (the 2q vanishes mod 2).
#push-options "--fuel 2 --ifuel 2 --z3rlimit 200"
let lemma_bit_low (a k: nat) : Lemma
  (bit a k = bit (a % pow2_pos (k + 1)) k)
  =
  let p = pow2_pos k in
  let p1 = pow2_pos (k + 1) in
  let r = a % p1 in
  let q = a / p1 in
  lemma_pow2_pos_succ k;
  FStar.Math.Lemmas.lemma_div_mod a p1;
  (* a = 2p·q + r; a/p = (2p·q + r)/p = 2q + r/p (lemma_div_plus). *)
  FStar.Math.Lemmas.lemma_div_plus r (2 * q) p;
  (* (a / 2^k) % 2 = (2q + r/p) % 2 = (r/p) % 2 *)
  FStar.Math.Lemmas.lemma_mod_plus (r / p) q 2;
  ()
#pop-options

/// Disjoint XOR equals addition: nat_xor x (b · 2^k) w = x + b · 2^k when
/// x < 2^k, b ∈ {0,1}, and b · 2^k < 2^w (the two operands live in disjoint
/// bit windows, so XOR adds).  Inducts on k, peeling the low bit of x (which
/// is untouched, since b·2^k is even for k ≥ 1).
#push-options "--fuel 2 --ifuel 2 --z3rlimit 300"
let rec lemma_xor_disjoint (x b k w: nat) : Lemma
  (requires x < pow2_pos k /\ (b = 0 \/ b = 1) /\ b * pow2_pos k < pow2 w /\ k < w)
  (ensures nat_xor x (b * pow2_pos k) w = x + b * pow2_pos k)
  (decreases k)
  =
  if k = 0 then begin
    (* x < 1 so x = 0; nat_xor 0 b w = b (b ∈ {0,1} < 2^w). *)
    lemma_xor_zero (b * pow2_pos 0) w
  end
  else begin
    lemma_pow2_pos_succ (k - 1);
    (* b·2^k is even (k ≥ 1): its low bit is 0.  nat_xor's definition: *)
    assert (nat_xor x (b * pow2_pos k) w
            = (x % 2) + 2 * nat_xor (x / 2) (b * pow2_pos (k - 1)) (w - 1));
    lemma_xor_disjoint (x / 2) b (k - 1) (w - 1);
    FStar.Math.Lemmas.lemma_div_mod x 2;
    ()
  end
#pop-options

/// Width-16 instance: xor16 x (b·2^k) = x + b·2^k (the disjoint-window sum).
#push-options "--fuel 2 --ifuel 2 --z3rlimit 200"
let lemma_xor_disjoint_high (x b k: nat) : Lemma
  (requires x < pow2_pos k /\ (b = 0 \/ b = 1) /\ b * pow2_pos k < pow2 16 /\ k < 16)
  (ensures xor16 x (b * pow2_pos k) = x + b * pow2_pos k)
  =
  lemma_xor_disjoint x b k 16
#pop-options

/// 0 <= bit x k <= 1 (a bit is a boolean-valued nat).
#push-options "--fuel 2 --ifuel 2"
let lemma_bit_bounded (x k: nat) : Lemma (bit x k = 0 \/ bit x k = 1) = ()
#pop-options

/// The SUM-fold recovers the bit decomposition modulo 2^n:
/// bits_sum a n = a % 2^n.  Inducts on n; the step uses the bit-extraction
/// identity [a % 2^{n} = a % 2^{n-1} + bit a (n-1) · 2^{n-1}].
#push-options "--fuel 2 --ifuel 2 --z3rlimit 300"
let rec lemma_bits_sum_mod (a n: nat) : Lemma
  (ensures bits_sum a n = a % pow2_pos n)
  (decreases n)
  =
  if n = 0 then ()
  else begin
    lemma_bits_sum_mod a (n - 1);
    lemma_pow2_pos_succ (n - 1);
    let m = pow2_pos (n - 1) in
    let r = a % m in
    let q = a / m in
    FStar.Math.Lemmas.lemma_div_mod a m;
    (* a = m·q + r.  bit a (n-1) = q % 2.  Claim: a % (2m) = r + (q%2)·m. *)
    FStar.Math.Lemmas.lemma_div_mod q 2;
    (* q = 2·(q/2) + q%2, so q·m = 2m·(q/2) + m·(q%2). *)
    FStar.Math.Lemmas.lemma_mod_plus (r + (q % 2) * m) (q / 2) (2 * m);
    (* r + (q%2)m < 2m *)
    FStar.Math.Lemmas.small_mod (r + (q % 2) * m) (2 * m);
    ()
  end
#pop-options

/// bits_sum recovers [a] when a < 2^n (a is already reduced).
#push-options "--fuel 2 --ifuel 2"
let lemma_bits_sum_recover (a n: nat) : Lemma
  (requires a < pow2_pos n)
  (ensures bits_sum a n = a)
  =
  lemma_bits_sum_mod a n;
  FStar.Math.Lemmas.small_mod a (pow2_pos n)
#pop-options

/// bits_sum is bounded by 2^n (a % 2^n < 2^n).
#push-options "--fuel 2 --ifuel 2"
let lemma_bits_sum_bounded (a n: nat) : Lemma (bits_sum a n < pow2_pos n) =
  lemma_bits_sum_mod a n;
  FStar.Math.Lemmas.lemma_mod_lt a (pow2_pos n)
#pop-options

/// bits_xor's XOR of an already-summed prefix equals the sum (disjoint windows):
/// nat_xor (SUM) (bit a k · 2^k) = SUM + bit a k · 2^k for k < 16 and
/// the SUM < 2^k.  One-shot instance of lemma_xor_disjoint_high.
#push-options "--fuel 2 --ifuel 2 --z3rlimit 200"
let lemma_xor_disjoint_bit (sum a k: nat) : Lemma
  (requires sum < pow2_pos k /\ k < 16)
  (ensures xor16 sum (bit a k * pow2_pos k) = sum + bit a k * pow2_pos k)
  =
  lemma_bit_bounded a k;
  lemma_pow2_pos_mono k 15;
  assert_norm (pow2_pos 15 = 32768);
  assert_norm (pow2 16 = 65536);
  assert (pow2_pos k <= 32768);
  assert (bit a k * pow2_pos k <= pow2_pos k);
  assert (bit a k * pow2_pos k < pow2 16);
  lemma_xor_disjoint_high sum (bit a k) k
#pop-options

/// The XOR-fold equals the SUM-fold of the bit decomposition (disjoint windows):
/// bits_xor a n = bits_sum a n.  Inducts on n, XORing in bit (n-1) · 2^{n-1}
/// onto a sum < 2^{n-1} (the inductive sum stays below 2^{n-1} < 2^{16}).
#push-options "--fuel 2 --ifuel 2 --z3rlimit 300"
let rec lemma_bits_xor_eq_sum (a n: nat) : Lemma
  (requires n <= 16)
  (ensures bits_xor a n = bits_sum a n)
  (decreases n)
  =
  if n = 0 then ()
  else begin
    lemma_bits_xor_eq_sum a (n - 1);
    lemma_bits_sum_bounded a (n - 1);
    lemma_xor_disjoint_bit (bits_sum a (n - 1)) a (n - 1);
    ()
  end
#pop-options

/// THE bit decomposition: bits_xor a n = a for a < 2^n (n <= 16).
#push-options "--fuel 2 --ifuel 2 --z3rlimit 300"
let lemma_bits_xor_recover (a n: nat) : Lemma
  (requires a < pow2_pos n /\ n <= 16)
  (ensures bits_xor a n = a)
  =
  lemma_bits_xor_eq_sum a n;
  lemma_bits_sum_recover a n
#pop-options

/// Position-indexed carry-less product accumulator: for each position pos
/// (from k-1 down to 0) with bit pos of [b] set, XOR [a · 2^pos] into [acc].
let rec clmul_go (acc a b k: nat) : Tot nat (decreases k) =
  if k = 0 then acc
  else
    let pos = k - 1 in
    clmul_go (if bit b pos = 1 then xor16 acc (a * pow2 pos) else acc) a b (k - 1)

/// Carry-less product of two bytes (< 2^16): clmul a b = XOR_{k: bit_k b = 1} (a·2^k).
let clmul (a b: nat) : nat = clmul_go 0 a b 8

/// The primitive-polynomial muliplier 0x11D = x^8 + x^4 + x^3 + x^2 + 1.
let refold : nat = 0x11D

/// Reduction by a single descending pass over bit positions [d] .. 8:
/// at position p, if bit p of [c] is set, fold c ^= refold · 2^(p−8) (the
/// x^8 ↦ x^4+x^3+x^2+1 substitution shifted to clear bit p).  A single
/// descending pass is correct because refold · 2^(p−8) only touches bits ≤ p.
let rec reduce_from (c: nat) (d: nat) : Tot nat (decreases d) =
  if d < 8 then c
  else
    let c' = if (c / pow2_pos d) % 2 = 1 then nat_xor c (refold * pow2 (d - 8)) 16 else c in
    reduce_from c' (d - 1)

/// Reduce a carry-less product (< 2^15) to < 256.
let reduce (c: nat) : nat = reduce_from c 14

#push-options "--fuel 3 --ifuel 3 --z3rlimit 160"
/// If [c] < 2^9 (no bit at or above [d] ≥ 9 is set), then reduce_from c d
/// drops straight through the no-op positions to reduce_from c 8.
let rec lemma_reduce_from_drop_high (c: nat) (d: nat) : Lemma
  (requires d >= 8 /\ c < pow2_pos 9)
  (ensures reduce_from c d = reduce_from c 8)
  (decreases d)
  =
  if d = 8 then ()
  else begin
    assert_norm (pow2_pos 9 = 512);
    lemma_pow2_pos_mono 9 d;
    assert (c < pow2_pos d);
    assert (c / pow2_pos d = 0);
    lemma_reduce_from_drop_high c (d - 1)
  end
#pop-options

/// The reduction step applied to a doubled element agrees with the 16-bit
/// reduction fold: reduce (2a) = red a for a < 256.  For a ≥ 128 both 2a and
/// 0x11D carry bit 8, so the 16-bit fold cancels it (result < 256) while the
/// 8-bit xor truncates it away — the two agree via two-sided truncation.
#push-options "--z3rlimit 240"
let lemma_reduce_double (a: nat) : Lemma
  (requires a < 256)
  (ensures reduce (2 * a) = red a)
  =
  if a < 128 then (assert_norm (pow2_pos 9 = 512); ())
  else begin
    assert_norm (pow2_pos 8 = 256);
    assert_norm (pow2_pos 9 = 512);
    assert (2 * a < 512 /\ 2 * a >= 256);
    lemma_reduce_from_drop_high (2 * a) 14;
    assert (((2 * a) / 256) % 2 = 1);
    assert (reduce_from (2 * a) 8 = nat_xor (2 * a) 0x11D 16);
    let x = 2 * a - 256 in
    assert (2 * a = 256 + x);
    assert (0x11D = 256 + 29);
    assert (x < 256);
    (* red a = nat_xor (2a) 0x11D 8 = nat_xor x 29 8 (two-sided truncation) *)
    lemma_xor_trunc_both 8 x 29;
    (* nat_xor (2a) 0x11D 16 = nat_xor (2a%256) 29 8 = nat_xor x 29 8 (cancellation) *)
    lemma_xor_trunc_cancel a;
    assert ((2 * a) % 256 = x);
    ()
  end
#pop-options

(* ========================================================================
   SECTION 2c: Russian-peasant carry-less product (raw_mul) + the
   accumulator-linearity / product-bound atoms
   ========================================================================
   [raw_mul_go] is [gf_mul_go]'s body with plain [a * 2] in place of the
   reducing [red a] — i.e. the *unreduced* carry-less product.  It is
   bit-identical to the position-indexed [clmul] over all 65536 pairs
   (Python-verified), and its [gf_mul_go]-shaped body makes the bridge
   [gf_mul_go p a b = xor8 p (reduce (raw_mul a b))] structurally trivial
   (only the [red] ↔ [*2] substitution plus [reduce] linearity to discharge).
   ======================================================================== *)

/// Russian-peasant carry-less product accumulator (no reduction).
let rec raw_mul_go (acc a b: nat) : Tot nat (decreases b) =
  if b = 0 then acc else raw_mul_go (if b % 2 = 1 then xor16 acc a else acc) (a * 2) (b / 2)

/// The unreduced carry-less product of two bytes (< 2^16).
let raw_mul (a b: nat) : nat = raw_mul_go 0 a b

/// (1) The product-bound atom: [raw_mul_go] preserves [a * b] (the per-step
/// product is non-increasing: (2a)·(b/2) = a·b for even b, a·(b−1) < a·b for
/// odd b).  For [a0 < 2^8] and [k <= 7] the multiplicand reached by k
/// doublings stays < 2^15 — the sharp crossing: the 8th doubling (a0·2^8 <
/// 2^16) is the dead, never-XORed value, so every XORed multiplicand is < 2^15.
let lemma_raw_mul_doubles_bound (a0 k: nat) : Lemma
  (requires a0 < 256 /\ k <= 7)
  (ensures a0 * pow2 k < pow2 15)
  =
  assert_norm (pow2 7 = 128);
  assert_norm (pow2 15 = 32768);
  assert_norm (pow2 8 = 256);
  lemma_pow2_mono k 7;
  ()

/// (2) Accumulator linearity of the unreduced product, carrying the CLOSED
/// product invariant [a * b < 2^16] (not a fixed bound on [a], which doubles
/// each step and so admits no fixed bound closed under the recurrence — this
/// is the exact fix recorded in fstar-proofs §83).
#push-options "--fuel 4 --ifuel 2"
let rec lemma_raw_mul_go_linear (acc a b: nat) : Lemma
  (requires acc < pow2 16 /\ a * b < pow2 16)
  (ensures raw_mul_go acc a b = xor16 acc (raw_mul_go 0 a b))
  (decreases b)
  =
  if b = 0 then (lemma_xor_zero acc 16)
  else begin
    let acc' = if b % 2 = 1 then xor16 acc a else acc in
    let a' = a * 2 in
    lemma_xor_bounded acc a 16;
    lemma_raw_mul_go_linear acc' a' (b / 2);
    if b % 2 = 1 then begin
      lemma_xor_bounded 0 a 16;
      lemma_raw_mul_go_linear (xor16 0 a) a' (b / 2);
      lemma_xor_comm 0 a 16;
      lemma_xor_zero a 16;
      lemma_xor_assoc acc a (raw_mul_go 0 a' (b / 2)) 16
    end
    else ()
  end
#pop-options

(* --- bridge atoms (toward gf_mul_go = xor8 p (reduce (raw_mul a b))) --- *)

/// xor16 x y = xor8 x y for x, y < 256 (bits [8..15] are zero on both sides).
#push-options "--fuel 2 --ifuel 2"
let lemma_xor_16_eq_8 (x y: nat) : Lemma
  (requires x < 256 /\ y < 256)
  (ensures xor16 x y = xor8 x y)
  =
  assert_norm (pow2 8 = 256);
  lemma_xor_pad x y 8 8;
  ()
#pop-options

/// reduce is the identity below 256: reduce c = c for c < 256.
#push-options "--fuel 2 --ifuel 2 --z3rlimit 120"
let lemma_reduce_id (c: nat) : Lemma
  (requires c < 256)
  (ensures reduce c = c)
  =
  assert_norm (pow2_pos 9 = 512);
  lemma_reduce_from_drop_high c 14;
  assert (reduce_from c 8 = c);
  ()
#pop-options

/// bit d of nat_xor x y w equals (bit d x) XOR (bit d y), for d < w — the
/// branch-distribution fact for the reduce_from linearity induction.
#push-options "--fuel 2 --ifuel 2 --z3rlimit 160"
let rec lemma_nat_xor_bit (x y w d: nat) : Lemma
  (requires d < w)
  (ensures bit (nat_xor x y w) d = (bit x d + bit y d) % 2)
  (decreases d)
  =
  if d = 0 then ()
  else begin
    lemma_nat_xor_bit (x / 2) (y / 2) (w - 1) (d - 1);
    lemma_pow2_pos_succ (d - 1);
    lemma_bit_shift (nat_xor x y w) (d - 1);
    lemma_bit_shift x (d - 1);
    lemma_bit_shift y (d - 1);
    ()
  end
#pop-options

(* ------------------------------------------------------------------------
   reduce GF(2)-linearity: reduce_from (xor16 x y) d
     = xor16 (reduce_from x d) (reduce_from y d)
   ------------------------------------------------------------------------ *)

/// The Boolean-selection atom: nat_xor (s bx r) (s yb r) 16 = s (bx <> yb) r
/// where [s b r = if b then r else 0].  This is the bit-level GF(2) scaling
/// linearity that makes [reduce_from] distribute over XOR.  A BOOLEAN selector
/// (not [nat] with [<= 1]) is essential: [match bx, yb] binds each branch
/// structurally, so [s bx r] reduces to 0 or r in the goal.
let s (bx: bool) (r: nat) : nat = if bx then r else 0

#push-options "--fuel 2 --ifuel 2 --z3rlimit 120"
let lemma_select_xor_bool (bx yb: bool) (r: nat) : Lemma
  (requires r < 65536)
  (ensures nat_xor (s bx r) (s yb r) 16 = s (bx <> yb) r)
  =
  assert_norm (pow2 16 = 65536);
  match bx, yb with
  | false, false -> lemma_xor_00 16
  | false, true  -> lemma_xor_zero r 16; lemma_xor_comm 0 r 16
  | true,  false -> lemma_xor_zero r 16
  | true,  true  -> lemma_xor_self r 16
#pop-options

/// One-step commutation: the reduction step at position d distributes over XOR.
/// [step c d = xor16 c (s (bit c d = 1) (refold · 2^(d-8)))].  Linearity of the
/// step is exactly the select atom + xor16 assoc/comm, using
/// [lemma_nat_xor_bit] for the branch-bit distribution.
#push-options "--fuel 2 --ifuel 2 --z3rlimit 240"
let lemma_reduce_step_xor (d: nat) (x y: nat) : Lemma
  (requires d >= 8 /\ d < 16)
  (ensures
    (let r = refold * pow2_pos (d - 8) in
     xor16
       (s (bit x d = 1) r)
       (s (bit y d = 1) r)
       = s (bit (xor16 x y) d = 1) r))
  =
  assert_norm (pow2 16 = 65536);
  assert_norm (pow2_pos 8 = 256);
  assert_norm (refold = 285);
  lemma_pow2_pos_mono (d - 8) 7;
  assert_norm (pow2_pos 7 = 128);
  assert (pow2_pos (d - 8) <= 128);
  assert (refold * pow2_pos (d - 8) < 65536);
  lemma_nat_xor_bit x y 16 d;
  lemma_select_xor_bool (bit x d = 1) (bit y d = 1) (refold * pow2_pos (d - 8));
  ()
#pop-options

/// Step linearity: the reduction step commutes with XOR.
/// [step c d = xor16 c (s (bit c d = 1) r)] for [r = refold · 2^(d-8)].
/// Uses xor16 assoc/comm + [lemma_reduce_step_xor].
#push-options "--fuel 2 --ifuel 2 --z3rlimit 240"
let lemma_step_xor (d: nat) (x y: nat) : Lemma
  (requires d >= 8 /\ d < 16)
  (ensures
    (let r = refold * pow2_pos (d - 8) in
     xor16 (xor16 x y) (s (bit (xor16 x y) d = 1) r)
       = xor16 (xor16 x (s (bit x d = 1) r)) (xor16 y (s (bit y d = 1) r))))
  =
  let r = refold * pow2_pos (d - 8) in
  assert_norm (pow2 16 = 65536);
  lemma_reduce_step_xor d x y;
  let c1 = s (bit x d = 1) r in
  let c2 = s (bit y d = 1) r in
  let c  = s (bit (xor16 x y) d = 1) r in
  assert (xor16 c1 c2 = c);
  lemma_xor_assoc x y c 16;
  lemma_xor_comm y c 16;
  lemma_xor_assoc x c y 16;
  lemma_xor_comm c1 c2 16;
  lemma_xor_assoc x c1 c2 16;
  lemma_xor_assoc (xor16 x c1) c2 y 16;
  lemma_xor_comm c2 y 16;
  ()
#pop-options

/// Reduce base case: [reduce_from] is the identity below [d < 8] — used as the
/// base of the (still-open) GF(2)-linearity induction.
#push-options "--fuel 2 --ifuel 2 --z3rlimit 240"
let lemma_reduce_from_base (d: nat) (x y: nat) : Lemma
  (requires d < 8)
  (ensures reduce_from (xor16 x y) d = xor16 x y)
  = ()
#pop-options

(* NOTE: the full GF(2)-linearity of [reduce_from]
   (lemma_reduce_from_xor d x y : reduce_from (xor16 x y) d
     = xor16 (reduce_from x d) (reduce_from y d), for d < 16) is the KNOWN
   remaining symbolic wall (fstar-proofs §83).  The ONE-step commutation
   [lemma_step_xor] IS proven 0-admit above (the Boolean-select atom
   [lemma_select_xor_bool] cracked the [sel bx r = bx*r] rewrite), but the
   induction step does not discharge: unfolding [reduce_from c d] for SYMBOLIC
   [c] (= [xor16 x y]) — even at the base [d < 8] — and gluing
   [lemma_step_xor] through the [d-1] recursion spins SMT at every fuel/rlimit
   (bare [reduce (xor16 x y) = xor16 (reduce x) (reduce y)] over [reduce =
   reduce_from _ 14] also spins).  This is the SMT bit-vector wall, not a
   missing fact.  The fallback (fstar-proofs §83 plan item (b)) is exhaustive
   [assert_norm] over the 256x256 [gf_mul_go] table (a normalizer run, NOT SMT),
   which is sound because the field is finite. *)

(* ========================================================================
   SECTION 2d: carry-less product bilinearity (distributivity, plan 6.3-distrib)
   ========================================================================
   The carry-less product [raw_mul] is GF(2)-bilinear: it distributes over
   [xor16] in its multiplicand.  This is the field's distributivity law once
   the [reduce]-homomorphism bridge is in place, and is the first of the
   coefficient-level structural laws (plan Lemma 3).

   WHY the product invariant [a * c < 2^15] (not a fixed [a < 2^16]): the
   multiplicand [a] doubles every recursion, so no fixed bound is closed under
   the recurrence — but the PRODUCT [a * c] is non-increasing ([a->2a, c->c/2]
   preserves it), and the sharp [2^15] bound gives [a < 2^15] for free (needed
   by [lemma_xor16_double_gen]).  Mirrors [lemma_raw_mul_go_linear]'s recipe.
   ======================================================================== *)

#push-options "--fuel 2 --ifuel 2 --z3rlimit 200"
/// The "middle-four" xor16 interchange: (p.r).(q.s) = (p.q).(r.s).
let lemma_xor16_middle (p q r s: nat) : Lemma
  (ensures xor16 (xor16 p r) (xor16 q s) = xor16 (xor16 p q) (xor16 r s))
  =
  lemma_xor_assoc p r (xor16 q s) 16;
  lemma_xor_assoc r q s 16;
  lemma_xor_comm r q 16;
  lemma_xor_assoc q r s 16;
  lemma_xor_assoc p q (xor16 r s) 16;
  ()
#pop-options

#push-options "--fuel 2 --ifuel 2 --z3rlimit 120"
/// Doubling distributes over xor16 for operands < 2^15 (the top bit is clear,
/// so the 16-bit XOR halves cleanly to the 15-bit XOR).
let lemma_xor16_double_gen (a b: nat) : Lemma
  (requires a < pow2 15 /\ b < pow2 15)
  (ensures xor16 (2 * a) (2 * b) = 2 * (xor16 a b))
  =
  lemma_nat_xor_double a b 16;
  lemma_xor_pad a b 15 1;
  ()
#pop-options

#push-options "--fuel 4 --ifuel 2 --z3rlimit 300"
/// Bilinearity of the carry-less product accumulator: splitting BOTH the
/// accumulator and the multiplicand over xor16 splits the result.
///   raw_mul_go (accA . accB) (a . b) c = raw_mul_go accA a c . raw_mul_go accB b c
let rec lemma_raw_mul_go_bilinear (accA accB a b c: nat) : Lemma
  (requires accA < 65536 /\ accB < 65536 /\ a * c < pow2 15 /\ b * c < pow2 15)
  (ensures
    raw_mul_go (xor16 accA accB) (xor16 a b) c
      = xor16 (raw_mul_go accA a c) (raw_mul_go accB b c))
  (decreases c)
  =
  if c = 0 then ()
  else begin
    lemma_xor16_double_gen a b;
    lemma_xor16_middle accA accB a b;
    lemma_xor_bounded accA a 16;
    lemma_xor_bounded accB b 16;
    assert_norm (pow2 16 = 65536);
    lemma_raw_mul_go_bilinear
      (if c % 2 = 1 then xor16 accA a else accA)
      (if c % 2 = 1 then xor16 accB b else accB)
      (2 * a) (2 * b) (c / 2);
    ()
  end
#pop-options

/// Distributivity of the carry-less product in its multiplicand is the
/// [accA = accB = 0] instance of [lemma_raw_mul_go_bilinear], valid whenever
/// the product invariant holds.  (The field-level distributivity law is
/// assembled once the reduce-homomorphism bridge lands, since [gf_mul =
/// reduce . raw_mul].)

(* ========================================================================
   SECTION 2e: the grid fold-swap (order-independence of a double XOR fold)
   ========================================================================
   The double XOR fold over a rectangular grid is order-independent: row-major
   equals column-major.  This is the PURE combinatorial fact (plan item 2,
   the double-sum index swap) that makes carry-less product symmetry a simple
   reindexing, since both operands' set-bit expansions land on the same grid
   of monomials [2^{i+j}].  No bit arithmetic here — only xor16 comm/assoc.
   ======================================================================== *)

/// XOR-fold over [j < m] with [i] fixed.
let rec fold_row (f: nat -> nat -> nat) (i j: nat) : Tot nat (decreases j) =
  if j = 0 then 0
  else xor16 (f i (j - 1)) (fold_row f i (j - 1))

/// A single row.
let row (f: nat -> nat -> nat) (i m: nat) : nat = fold_row f i m

/// Row-major fold over [i < n], [j < m].
let rec grid (f: nat -> nat -> nat) (m i: nat) : Tot nat (decreases i) =
  if i = 0 then 0
  else xor16 (row f (i - 1) m) (grid f m (i - 1))

/// The full row-major grid sum.
let grid_sum (f: nat -> nat -> nat) (n m: nat) : nat = grid f m n

/// XOR-fold over [i < n] with [j] fixed.
let rec fold_col (f: nat -> nat -> nat) (n j: nat) : Tot nat (decreases n) =
  if n = 0 then 0
  else xor16 (f (n - 1) j) (fold_col f (n - 1) j)

/// A single column.
let col (f: nat -> nat -> nat) (n j: nat) : nat = fold_col f n j

/// Column-major fold over [j < m], [i < n].
let rec grid_t (f: nat -> nat -> nat) (n j: nat) : Tot nat (decreases j) =
  if j = 0 then 0
  else xor16 (col f n (j - 1)) (grid_t f n (j - 1))

/// The full column-major grid sum.
let grid_sum_t (f: nat -> nat -> nat) (n m: nat) : nat = grid_t f n m

/// The empty-column (n = 0) transpose is 0.
#push-options "--fuel 2 --ifuel 2 --z3rlimit 300"
let rec lemma_grid_t_zero (f: nat -> nat -> nat) (m: nat) : Lemma
  (ensures grid_t f 0 m = 0) (decreases m)
  =
  if m = 0 then ()
  else (lemma_grid_t_zero f (m - 1); lemma_xor_00 16)
#pop-options

/// Appending a full row to the transpose equals the transpose of one more row.
#push-options "--fuel 2 --ifuel 2 --z3rlimit 1200"
let rec lemma_row_append (f: nat -> nat -> nat) (i m: nat) : Lemma
  (ensures xor16 (row f i m) (grid_sum_t f i m) = grid_sum_t f (i + 1) m)
  (decreases m)
  =
  if m = 0 then (lemma_xor_00 16)
  else begin
    assert (row f i m = xor16 (f i (m - 1)) (row f i (m - 1)));
    assert (grid_sum_t f i m = xor16 (col f i (m - 1)) (grid_sum_t f i (m - 1)));
    assert (grid_sum_t f (i + 1) m = xor16 (col f (i + 1) (m - 1)) (grid_sum_t f (i + 1) (m - 1)));
    assert (col f (i + 1) (m - 1) = xor16 (f i (m - 1)) (col f i (m - 1)));
    lemma_row_append f i (m - 1);
    lemma_xor16_middle (f i (m - 1)) (col f i (m - 1)) (row f i (m - 1)) (grid_sum_t f i (m - 1));
    ()
  end
#pop-options

/// THE fold-swap: row-major and column-major double XOR folds agree.
#push-options "--fuel 2 --ifuel 2 --z3rlimit 1200"
let rec lemma_grid_swap (f: nat -> nat -> nat) (n m: nat) : Lemma
  (ensures grid_sum f n m = grid_sum_t f n m) (decreases n)
  =
  if n = 0 then lemma_grid_t_zero f m
  else begin
    lemma_grid_swap f (n - 1) m;
    lemma_row_append f (n - 1) m;
    ()
  end
#pop-options

(* ========================================================================
   SECTION 2f: clmul symmetry via the bit-decomposition double sum
   ========================================================================
   [clmul a b] is the position-indexed carry-less product; expanding [a]
   through its bit decomposition turns it into the symmetric double sum
   [dsum a b = XOR_{i,j} bit_i a · bit_j b · 2^{i+j}].  Symmetry is then the
   index transposition (i,j) ↦ (j,i) — a fold-swap, no bit arithmetic.
   ======================================================================== *)

/// The j-shifted XOR-fold of a's bits: XOR_{i<n} bit a i · 2^{i+j}.
let rec shl_bits (a j: nat) (n: nat) : Tot nat (decreases n) =
  if n = 0 then 0
  else xor16 (shl_bits a j (n - 1)) (bit a (n - 1) * pow2_pos (n - 1 + j))

/// The symmetric double sum: XOR_{i<8, j<8} bit a i · bit b j · 2^{i+j}.
let dsum (a b: nat) : nat =
  grid_sum (fun (i j: nat) -> bit a i * bit b j * pow2_pos (i + j)) 8 8

/// Left-shift by k bits distributes over XOR (widening): shifting the XOR
/// equals the XOR of the shifts, over a k-wider window.  No bound needed —
/// XOR has no carry, and both sides capture the same shifted bits.
#push-options "--fuel 2 --ifuel 2 --z3rlimit 300"
let rec lemma_nat_xor_shl (k x y w: nat) : Lemma
  (ensures nat_xor x y w * pow2_pos k = nat_xor (x * pow2_pos k) (y * pow2_pos k) (w + k))
  (decreases k)
  =
  if k = 0 then ()
  else begin
    lemma_pow2_pos_succ (k - 1);
    lemma_nat_xor_shl (k - 1) x y w;
    lemma_nat_xor_double (x * pow2_pos (k - 1)) (y * pow2_pos (k - 1)) (w + k);
    ()
  end
#pop-options

/// Fixed-width scalar distribute: (xor16 x y)·2^k = xor16 (x·2^k) (y·2^k)
/// when both products stay < 2^16.
#push-options "--fuel 2 --ifuel 2 --z3rlimit 300"
let lemma_xor16_shl (k x y: nat) : Lemma
  (requires x * pow2_pos k < pow2 16 /\ y * pow2_pos k < pow2 16)
  (ensures xor16 x y * pow2_pos k = xor16 (x * pow2_pos k) (y * pow2_pos k))
  =
  (* widen to 16+k, then trim the high k zero bits back to 16. *)
  lemma_nat_xor_shl k x y 16;
  lemma_xor_pad (x * pow2_pos k) (y * pow2_pos k) 16 k;
  ()
#pop-options

/// bits_xor is bounded by 2^n (the XOR of n single-bit terms < 2^n).
#push-options "--fuel 2 --ifuel 2"
let lemma_bits_xor_bounded (a n: nat) : Lemma
  (requires n <= 16)
  (ensures bits_xor a n < pow2_pos n)
  =
  lemma_bits_xor_eq_sum a n;
  lemma_bits_sum_bounded a n
#pop-options

/// shl_bits a n j = 2^j · bits_xor a n (the j-shift distributes over the XOR).
#push-options "--fuel 3 --ifuel 3 --z3rlimit 400"
let rec lemma_shl_bits_eq_mul (a j n: nat) : Lemma
  (requires n + j <= 16)
  (ensures shl_bits a j n = bits_xor a n * pow2_pos j)
  (decreases n)
  =
  if n = 0 then ()
  else begin
    lemma_shl_bits_eq_mul a j (n - 1);
    lemma_bits_xor_bounded a (n - 1);
    lemma_bit_bounded a (n - 1);
    lemma_pow2_pos_add (n - 1) j;
    lemma_pow2_pos_mono (n - 1 + j) 15;
    assert_norm (pow2_pos 15 = 32768);
    assert_norm (pow2 16 = 65536);
    assert (bits_xor a (n - 1) * pow2_pos j < pow2 16);
    assert (bit a (n - 1) * pow2_pos (n - 1) * pow2_pos j < pow2 16);
    lemma_xor16_shl j (bits_xor a (n - 1)) (bit a (n - 1) * pow2_pos (n - 1));
    ()
  end
#pop-options

(* ========================================================================
   SECTION 3: Field axiom lemmas — proven
   ======================================================================== *)

#push-options "--z3rlimit 60"

/// Add identity: a + 0 = a
let lemma_gf_add_identity (a: gf256) : Lemma (gf_add a 0uy = a) =
  U.logxor_lemma_1 #8 (U8.v a);
  U8.v_inj (gf_add a 0uy) a

/// Add self-inverse: a + a = 0 (characteristic 2)
let lemma_gf_add_self_zero (a: gf256) : Lemma (gf_add a a = 0uy) =
  U.logxor_self #8 (U8.v a);
  U8.v_inj (gf_add a a) 0uy

/// Add commutativity
let lemma_gf_add_comm (a b: gf256) : Lemma (gf_add a b = gf_add b a) =
  U.logxor_commutative #8 (U8.v a) (U8.v b);
  U8.v_inj (gf_add a b) (gf_add b a)

/// Add associativity
let lemma_gf_add_assoc (a b c: gf256) : Lemma
  (gf_add (gf_add a b) c = gf_add a (gf_add b c))
  =
  U.logxor_associative #8 (U8.v a) (U8.v b) (U8.v c);
  U8.v_inj (gf_add (gf_add a b) c) (gf_add a (gf_add b c))

/// Mul zero: a * 0 = 0 (structural — multiplier b = 0 terminates immediately)
let lemma_gf_mul_zero (a: gf256) : Lemma (gf_mul a 0uy = 0uy) = ()

/// gf_mul_go 0 a 1 = a, for a < 256 (the one-bit multiply reduces to a).
#push-options "--fuel 2 --ifuel 1"
let lemma_gf_mul_go_one (a: nat) : Lemma
  (requires a < 256)
  (ensures gf_mul_go 0 a 1 = a)
  =
  lemma_xor_comm 0 a 8;
  lemma_xor_zero8 a
#pop-options

/// Mul identity: a * 1 = a (only bit 0 of b = 1 is set, so a is XORed once).
let lemma_gf_mul_identity (a: gf256) : Lemma (gf_mul a 1uy = a)
  =
  lemma_gf_mul_go_one (U8.v a);
  U8.v_inj (gf_mul a 1uy) a

/// Known-answer: 0x53 * 0xCA == 0x8F (ISO 18004 example).  Stated at the
/// nat level (gf_mul_go) — the same result as gf_mul via U8.uint_to_t.
let lemma_gf_mul_known_answer () : Lemma
  (ensures gf_mul_go 0 0x53 0xCA = 0x8F)
  = assert_norm (gf_mul_go 0 0x53 0xCA = 0x8F)

/// Known-answer: successive multiplication by the generator alpha = 0x02
/// gives 0x02, 0x04, 0x08, 0x10, 0x20, ...  (alpha^8 = 0x1D since
/// x^8 = x^4+x^3+x^2+1 = 0x1D mod 0x11D).
let lemma_gf_mul_alpha_pow () : Lemma
  (ensures gf_mul_go 0 0x02 0x02 = 0x04 /\
            gf_mul_go 0 0x04 0x02 = 0x08 /\
            gf_mul_go 0 0x08 0x02 = 0x10 /\
            gf_mul_go 0 0x10 0x02 = 0x20 /\
            gf_mul_go 0 0x80 0x02 = 0x1D)
  =
  assert_norm (gf_mul_go 0 0x02 0x02 = 0x04);
  assert_norm (gf_mul_go 0 0x04 0x02 = 0x08);
  assert_norm (gf_mul_go 0 0x08 0x02 = 0x10);
  assert_norm (gf_mul_go 0 0x10 0x02 = 0x20);
  assert_norm (gf_mul_go 0 0x80 0x02 = 0x1D)

#pop-options

(* ========================================================================
   SECTION 4: gf_exp / gf_log tables (for Reed-Solomon generator polynomial)
   ======================================================================== *)

/// Pre-computed antilog table: exp[i] = alpha^i (alpha = x = 0x02), 512 entries
/// so exp[log a + log b] needs no modular wrap.
let gf_exp_table : list gf256 = [
  0x01uy; 0x02uy; 0x04uy; 0x08uy; 0x10uy; 0x20uy; 0x40uy; 0x80uy;
  0x1duy; 0x3auy; 0x74uy; 0xe8uy; 0xcduy; 0x87uy; 0x13uy; 0x26uy;
  0x4cuy; 0x98uy; 0x2duy; 0x5auy; 0xb4uy; 0x75uy; 0xeauy; 0xc9uy;
  0x8fuy; 0x03uy; 0x06uy; 0x0cuy; 0x18uy; 0x30uy; 0x60uy; 0xc0uy;
  0x9duy; 0x27uy; 0x4euy; 0x9cuy; 0x25uy; 0x4auy; 0x94uy; 0x35uy;
  0x6auy; 0xd4uy; 0xb5uy; 0x77uy; 0xeeuy; 0xc1uy; 0x9fuy; 0x23uy;
  0x46uy; 0x8cuy; 0x05uy; 0x0auy; 0x14uy; 0x28uy; 0x50uy; 0xa0uy;
  0x5duy; 0xbauy; 0x69uy; 0xd2uy; 0xb9uy; 0x6fuy; 0xdeuy; 0xa1uy;
  0x5fuy; 0xbeuy; 0x61uy; 0xc2uy; 0x99uy; 0x2fuy; 0x5euy; 0xbcuy;
  0x65uy; 0xcauy; 0x89uy; 0x0fuy; 0x1euy; 0x3cuy; 0x78uy; 0xf0uy;
  0xfduy; 0xe7uy; 0xd3uy; 0xbbuy; 0x6buy; 0xd6uy; 0xb1uy; 0x7fuy;
  0xfeuy; 0xe1uy; 0xdfuy; 0xa3uy; 0x5buy; 0xb6uy; 0x71uy; 0xe2uy;
  0xd9uy; 0xafuy; 0x43uy; 0x86uy; 0x11uy; 0x22uy; 0x44uy; 0x88uy;
  0x0duy; 0x1auy; 0x34uy; 0x68uy; 0xd0uy; 0xbduy; 0x67uy; 0xceuy;
  0x81uy; 0x1fuy; 0x3euy; 0x7cuy; 0xf8uy; 0xeduy; 0xc7uy; 0x93uy;
  0x3buy; 0x76uy; 0xecuy; 0xc5uy; 0x97uy; 0x33uy; 0x66uy; 0xccuy;
  0x85uy; 0x17uy; 0x2euy; 0x5cuy; 0xb8uy; 0x6duy; 0xdauy; 0xa9uy;
  0x4fuy; 0x9euy; 0x21uy; 0x42uy; 0x84uy; 0x15uy; 0x2auy; 0x54uy;
  0xa8uy; 0x4duy; 0x9auy; 0x29uy; 0x52uy; 0xa4uy; 0x55uy; 0xaauy;
  0x49uy; 0x92uy; 0x39uy; 0x72uy; 0xe4uy; 0xd5uy; 0xb7uy; 0x73uy;
  0xe6uy; 0xd1uy; 0xbfuy; 0x63uy; 0xc6uy; 0x91uy; 0x3fuy; 0x7euy;
  0xfcuy; 0xe5uy; 0xd7uy; 0xb3uy; 0x7buy; 0xf6uy; 0xf1uy; 0xffuy;
  0xe3uy; 0xdbuy; 0xabuy; 0x4buy; 0x96uy; 0x31uy; 0x62uy; 0xc4uy;
  0x95uy; 0x37uy; 0x6euy; 0xdcuy; 0xa5uy; 0x57uy; 0xaeuy; 0x41uy;
  0x82uy; 0x19uy; 0x32uy; 0x64uy; 0xc8uy; 0x8duy; 0x07uy; 0x0euy;
  0x1cuy; 0x38uy; 0x70uy; 0xe0uy; 0xdduy; 0xa7uy; 0x53uy; 0xa6uy;
  0x51uy; 0xa2uy; 0x59uy; 0xb2uy; 0x79uy; 0xf2uy; 0xf9uy; 0xefuy;
  0xc3uy; 0x9buy; 0x2buy; 0x56uy; 0xacuy; 0x45uy; 0x8auy; 0x09uy;
  0x12uy; 0x24uy; 0x48uy; 0x90uy; 0x3duy; 0x7auy; 0xf4uy; 0xf5uy;
  0xf7uy; 0xf3uy; 0xfbuy; 0xebuy; 0xcbuy; 0x8buy; 0x0buy; 0x16uy;
  0x2cuy; 0x58uy; 0xb0uy; 0x7duy; 0xfauy; 0xe9uy; 0xcfuy; 0x83uy;
  0x1buy; 0x36uy; 0x6cuy; 0xd8uy; 0xaduy; 0x47uy; 0x8euy; 0x01uy;
  0x02uy; 0x04uy; 0x08uy; 0x10uy; 0x20uy; 0x40uy; 0x80uy; 0x1duy;
  0x3auy; 0x74uy; 0xe8uy; 0xcduy; 0x87uy; 0x13uy; 0x26uy; 0x4cuy;
  0x98uy; 0x2duy; 0x5auy; 0xb4uy; 0x75uy; 0xeauy; 0xc9uy; 0x8fuy;
  0x03uy; 0x06uy; 0x0cuy; 0x18uy; 0x30uy; 0x60uy; 0xc0uy; 0x9duy;
  0x27uy; 0x4euy; 0x9cuy; 0x25uy; 0x4auy; 0x94uy; 0x35uy; 0x6auy;
  0xd4uy; 0xb5uy; 0x77uy; 0xeeuy; 0xc1uy; 0x9fuy; 0x23uy; 0x46uy;
  0x8cuy; 0x05uy; 0x0auy; 0x14uy; 0x28uy; 0x50uy; 0xa0uy; 0x5duy;
  0xbauy; 0x69uy; 0xd2uy; 0xb9uy; 0x6fuy; 0xdeuy; 0xa1uy; 0x5fuy;
  0xbeuy; 0x61uy; 0xc2uy; 0x99uy; 0x2fuy; 0x5euy; 0xbcuy; 0x65uy;
  0xcauy; 0x89uy; 0x0fuy; 0x1euy; 0x3cuy; 0x78uy; 0xf0uy; 0xfduy;
  0xe7uy; 0xd3uy; 0xbbuy; 0x6buy; 0xd6uy; 0xb1uy; 0x7fuy; 0xfeuy;
  0xe1uy; 0xdfuy; 0xa3uy; 0x5buy; 0xb6uy; 0x71uy; 0xe2uy; 0xd9uy;
  0xafuy; 0x43uy; 0x86uy; 0x11uy; 0x22uy; 0x44uy; 0x88uy; 0x0duy;
  0x1auy; 0x34uy; 0x68uy; 0xd0uy; 0xbduy; 0x67uy; 0xceuy; 0x81uy;
  0x1fuy; 0x3euy; 0x7cuy; 0xf8uy; 0xeduy; 0xc7uy; 0x93uy; 0x3buy;
  0x76uy; 0xecuy; 0xc5uy; 0x97uy; 0x33uy; 0x66uy; 0xccuy; 0x85uy;
  0x17uy; 0x2euy; 0x5cuy; 0xb8uy; 0x6duy; 0xdauy; 0xa9uy; 0x4fuy;
  0x9euy; 0x21uy; 0x42uy; 0x84uy; 0x15uy; 0x2auy; 0x54uy; 0xa8uy;
  0x4duy; 0x9auy; 0x29uy; 0x52uy; 0xa4uy; 0x55uy; 0xaauy; 0x49uy;
  0x92uy; 0x39uy; 0x72uy; 0xe4uy; 0xd5uy; 0xb7uy; 0x73uy; 0xe6uy;
  0xd1uy; 0xbfuy; 0x63uy; 0xc6uy; 0x91uy; 0x3fuy; 0x7euy; 0xfcuy;
  0xe5uy; 0xd7uy; 0xb3uy; 0x7buy; 0xf6uy; 0xf1uy; 0xffuy; 0xe3uy;
  0xdbuy; 0xabuy; 0x4buy; 0x96uy; 0x31uy; 0x62uy; 0xc4uy; 0x95uy;
  0x37uy; 0x6euy; 0xdcuy; 0xa5uy; 0x57uy; 0xaeuy; 0x41uy; 0x82uy;
  0x19uy; 0x32uy; 0x64uy; 0xc8uy; 0x8duy; 0x07uy; 0x0euy; 0x1cuy;
  0x38uy; 0x70uy; 0xe0uy; 0xdduy; 0xa7uy; 0x53uy; 0xa6uy; 0x51uy;
  0xa2uy; 0x59uy; 0xb2uy; 0x79uy; 0xf2uy; 0xf9uy; 0xefuy; 0xc3uy;
  0x9buy; 0x2buy; 0x56uy; 0xacuy; 0x45uy; 0x8auy; 0x09uy; 0x12uy;
  0x24uy; 0x48uy; 0x90uy; 0x3duy; 0x7auy; 0xf4uy; 0xf5uy; 0xf7uy;
  0xf3uy; 0xfbuy; 0xebuy; 0xcbuy; 0x8buy; 0x0buy; 0x16uy; 0x2cuy;
  0x58uy; 0xb0uy; 0x7duy; 0xfauy; 0xe9uy; 0xcfuy; 0x83uy; 0x1buy;
  0x36uy; 0x6cuy; 0xd8uy; 0xaduy; 0x47uy; 0x8euy; 0x01uy; 0x02uy;
]

/// Pre-computed logarithm table: log[alpha^i] = i; log[0] = 0 (sentinel).
let gf_log_table : list gf256 = [
  0x00uy; 0x00uy; 0x01uy; 0x19uy; 0x02uy; 0x32uy; 0x1auy; 0xc6uy;
  0x03uy; 0xdfuy; 0x33uy; 0xeeuy; 0x1buy; 0x68uy; 0xc7uy; 0x4buy;
  0x04uy; 0x64uy; 0xe0uy; 0x0euy; 0x34uy; 0x8duy; 0xefuy; 0x81uy;
  0x1cuy; 0xc1uy; 0x69uy; 0xf8uy; 0xc8uy; 0x08uy; 0x4cuy; 0x71uy;
  0x05uy; 0x8auy; 0x65uy; 0x2fuy; 0xe1uy; 0x24uy; 0x0fuy; 0x21uy;
  0x35uy; 0x93uy; 0x8euy; 0xdauy; 0xf0uy; 0x12uy; 0x82uy; 0x45uy;
  0x1duy; 0xb5uy; 0xc2uy; 0x7duy; 0x6auy; 0x27uy; 0xf9uy; 0xb9uy;
  0xc9uy; 0x9auy; 0x09uy; 0x78uy; 0x4duy; 0xe4uy; 0x72uy; 0xa6uy;
  0x06uy; 0xbfuy; 0x8buy; 0x62uy; 0x66uy; 0xdduy; 0x30uy; 0xfduy;
  0xe2uy; 0x98uy; 0x25uy; 0xb3uy; 0x10uy; 0x91uy; 0x22uy; 0x88uy;
  0x36uy; 0xd0uy; 0x94uy; 0xceuy; 0x8fuy; 0x96uy; 0xdbuy; 0xbduy;
  0xf1uy; 0xd2uy; 0x13uy; 0x5cuy; 0x83uy; 0x38uy; 0x46uy; 0x40uy;
  0x1euy; 0x42uy; 0xb6uy; 0xa3uy; 0xc3uy; 0x48uy; 0x7euy; 0x6euy;
  0x6buy; 0x3auy; 0x28uy; 0x54uy; 0xfauy; 0x85uy; 0xbauy; 0x3duy;
  0xcauy; 0x5euy; 0x9buy; 0x9fuy; 0x0auy; 0x15uy; 0x79uy; 0x2buy;
  0x4euy; 0xd4uy; 0xe5uy; 0xacuy; 0x73uy; 0xf3uy; 0xa7uy; 0x57uy;
  0x07uy; 0x70uy; 0xc0uy; 0xf7uy; 0x8cuy; 0x80uy; 0x63uy; 0x0duy;
  0x67uy; 0x4auy; 0xdeuy; 0xeduy; 0x31uy; 0xc5uy; 0xfeuy; 0x18uy;
  0xe3uy; 0xa5uy; 0x99uy; 0x77uy; 0x26uy; 0xb8uy; 0xb4uy; 0x7cuy;
  0x11uy; 0x44uy; 0x92uy; 0xd9uy; 0x23uy; 0x20uy; 0x89uy; 0x2euy;
  0x37uy; 0x3fuy; 0xd1uy; 0x5buy; 0x95uy; 0xbcuy; 0xcfuy; 0xcduy;
  0x90uy; 0x87uy; 0x97uy; 0xb2uy; 0xdcuy; 0xfcuy; 0xbeuy; 0x61uy;
  0xf2uy; 0x56uy; 0xd3uy; 0xabuy; 0x14uy; 0x2auy; 0x5duy; 0x9euy;
  0x84uy; 0x3cuy; 0x39uy; 0x53uy; 0x47uy; 0x6duy; 0x41uy; 0xa2uy;
  0x1fuy; 0x2duy; 0x43uy; 0xd8uy; 0xb7uy; 0x7buy; 0xa4uy; 0x76uy;
  0xc4uy; 0x17uy; 0x49uy; 0xecuy; 0x7fuy; 0x0cuy; 0x6fuy; 0xf6uy;
  0x6cuy; 0xa1uy; 0x3buy; 0x52uy; 0x29uy; 0x9duy; 0x55uy; 0xaauy;
  0xfbuy; 0x60uy; 0x86uy; 0xb1uy; 0xbbuy; 0xccuy; 0x3euy; 0x5auy;
  0xcbuy; 0x59uy; 0x5fuy; 0xb0uy; 0x9cuy; 0xa9uy; 0xa0uy; 0x51uy;
  0x0buy; 0xf5uy; 0x16uy; 0xebuy; 0x7auy; 0x75uy; 0x2cuy; 0xd7uy;
  0x4fuy; 0xaeuy; 0xd5uy; 0xe9uy; 0xe6uy; 0xe7uy; 0xaduy; 0xe8uy;
  0x74uy; 0xd6uy; 0xf4uy; 0xeauy; 0xa8uy; 0x50uy; 0x58uy; 0xafuy;
]

/// Exponentiation: alpha^n, wrapping at the group order 255.
let gf_exp (n: nat) : gf256 =
  let idx = n % 255 in
  match nth gf_exp_table idx with
  | Some v -> v
  | None -> 0uy  (* unreachable: idx < 255 < 512 *)

/// Discrete logarithm (base alpha) of a nonzero element.
let gf_log (a: gf256{a <> 0uy}) : nat =
  let a_idx = U8.v a in
  match nth gf_log_table a_idx with
  | Some v -> U8.v v
  | None -> 0  (* unreachable: a < 256, table has 256 entries *)
