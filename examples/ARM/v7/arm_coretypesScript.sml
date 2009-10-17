(* ------------------------------------------------------------------------ *)
(*     ARM Machine Code Semantics                                           *)
(*     ==========================                                           *)
(*     Basic types and operations for the ARM model                         *)
(* ------------------------------------------------------------------------ *)

open HolKernel boolLib bossLib Parse;
open arithmeticTheory bitTheory wordsTheory wordsLib;

val _ = new_theory "arm_coretypes";

(* ------------------------------------------------------------------------ *)

val _ = Hol_datatype `RName =
    RName_0usr  | RName_1usr  | RName_2usr  | RName_3usr
  | RName_4usr  | RName_5usr  | RName_6usr  | RName_7usr
  | RName_8usr  | RName_8fiq  | RName_9usr  | RName_9fiq
  | RName_10usr | RName_10fiq | RName_11usr | RName_11fiq
  | RName_12usr | RName_12fiq
  | RName_SPusr | RName_SPfiq | RName_SPirq | RName_SPsvc
  | RName_SPabt | RName_SPund | RName_SPmon
  | RName_LRusr | RName_LRfiq | RName_LRirq | RName_LRsvc
  | RName_LRabt | RName_LRund | RName_LRmon
  | RName_PC`;

val _ = Hol_datatype `PSRName =
  CPSR | SPSR_fiq | SPSR_irq | SPSR_svc | SPSR_mon | SPSR_abt | SPSR_und`;

val _ = Hol_datatype `ARMpsr =
  <| N  : bool;  Z : bool; C : bool; V : bool; Q : bool;
     IT : word8; J : bool; Reserved : word4; GE : word4;
     E  : bool;  A : bool; I : bool; F : bool; T : bool; M : word5 |>`;

val _ = Hol_datatype `CP15sctlr =
  <| IE : bool; TE : bool; AFE : bool; TRE : bool; NMFI : bool;
     EE : bool; VE : bool; U   : bool; FI  : bool; DZ   : bool;
     HA : bool; RR : bool; V   : bool; I   : bool; Z    : bool;
     SW : bool; B  : bool; C   : bool; A   : bool; M    : bool |>`;

val _ = Hol_datatype `CP15scr =
  <| nET : bool; AW  : bool; FW : bool; EA  : bool;
     FIQ : bool; IRQ : bool; NS : bool |>`;

val _ = Hol_datatype `CP15nsacr =
  <| RFR : bool; NSASEDIS : bool; NSD32DIS : bool; cp : 14 word |>`;

val _ = Hol_datatype `CP15vbar =
  <| secure : word32; non_secure : word32 |>`;

val _ = Hol_datatype `CP15reg =
   <| SCTLR : CP15sctlr;
      SCR   : CP15scr;
      NSACR : CP15nsacr;
      VBAR  : CP15vbar;
      MVBAR : word32 |>`;

val _ = Hol_datatype `ARMarch =
    ARMv4   | ARMv4T
  | ARMv5T  | ARMv5TE
  | ARMv6   | ARMv6K  | ARMv6T2
  | ARMv7_A | ARMv7_R | ARMv7_M`;

val _ = Hol_datatype `ARMextensions =
    Extension_ThumbEE  | Extension_VFP     | Extension_AdvanvedSIMD
  | Extension_Security | Extension_Jazelle | Extension_Multiprocessing`;

val _ = Hol_datatype `ARMinfo =
  <| arch              : ARMarch;
     extensions        : ARMextensions set;
     unaligned_support : bool |>`;

val _ = Hol_datatype `SRType =
    SRType_LSL
  | SRType_LSR
  | SRType_ASR
  | SRType_ROR
  | SRType_RRX`;

val _ = Hol_datatype `InstrSet =
  InstrSet_ARM | InstrSet_Thumb | InstrSet_Jazelle | InstrSet_ThumbEE`;

val _ = Hol_datatype `Encoding =
  Encoding_ARM | Encoding_Thumb | Encoding_Thumb2`;

val _ = Hol_datatype `MemType =
  MemType_Normal | MemType_Device | MemType_StronglyOrdered`;

val _ = Hol_datatype `MemoryAttributes =
  <| type           : MemType;
     innerattrs     : word2;
     outerattrs     : word2;
     shareable      : bool;
     outershareable : bool |>`;

(*
val _ = Hol_datatype `FullAddress =
  <| physicaladdress    : word32;
     physicaladdressext : word8;
     NS                 : bool  (* F = Secure; T = Non-secure *) |>`;
*)

(* For now, assume that a full address is word32 *)
val _ = type_abbrev("FullAddress", ``:word32``);

val _ = Hol_datatype `AddressDescriptor =
  <| memattrs : MemoryAttributes;
     paddress : FullAddress |>`;

val _ = Hol_datatype `MBReqDomain =
    MBReqDomain_FullSystem
  | MBReqDomain_OuterShareable
  | MBReqDomain_InnerShareable
  | MBReqDomain_Nonshareable`;

val _ = Hol_datatype `MBReqTypes = MBReqTypes_All | MBReqTypes_Writes`;

val _ = Hol_datatype `memory_access =
  MEM_READ of FullAddress | MEM_WRITE of FullAddress => word8`;

(* Coprocessors *)

val _ = type_abbrev("cpid", ``:word4``);

val _ = type_abbrev ("proc", ``:num``);

val _ = Hol_datatype `iiid = <| proc : num |>`;

val _ = disable_tyabbrev_printing "proc";

(* ------------------------------------------------------------------------ *)

val sign_extend_def = Define`
  sign_extend n (w:'a word) = 
    n2w (SIGN_EXTEND n (dimindex(:'a)) (w2n w)) : 'a word`;

val align_def = with_flag (computeLib.auto_import_definitions,false) Define
  `align (w : 'a word, n : num) : 'a word = n2w (n * (w2n w DIV n))`;

val aligned_def = with_flag (computeLib.auto_import_definitions,false) Define`
  aligned (w : 'a word, n : num) = (w = align(w,n))`;

val count_leading_zeroes_def = Define`
  count_leading_zeroes (w : 'a word) =
    if w = 0w then
      dimindex(:'a)
    else
      dimindex(:'a) - 1 - LOG2 (w2n w)`;

val lowest_set_bit_def = Define`
  lowest_set_bit (w : 'a word) =
    if w = 0w then
      dimindex(:'a)
    else
      LEAST i. w ' i`;

val bit_count_upto_def = Define`
  bit_count_upto n (w : 'a word) = SUM n (\i. if w ' i then 1 else 0)`;

val bit_count_def = Define`
  bit_count (w : 'a word) = bit_count_upto (dimindex(:'a)) w`;

val _ = wordsLib.guess_lengths();

val zero_extend32_def = Define`
  (zero_extend32 [b:word8] : word32 = w2w b) /\
  (zero_extend32 [b1; b2] = w2w (b2 @@ b1))`;

val sign_extend32_def = Define`
  (sign_extend32 [b:word8] : word32 = sw2sw b) /\
  (sign_extend32 [b1; b2] = sw2sw (b2 @@ b1))`;

val word_defs = TotalDefn.multiDefine`
  (word16 ([b1; b2] : word8 list) = b2 @@ b1) /\
  (word32 ([b1; b2; b3; b4] : word8 list) = b4 @@ b3 @@ b2 @@ b1) /\
  (word64 ([b1; b2; b3; b4; b5; b6; b7; b8] : word8 list) =
    word32 [b5; b6; b7; b8] @@ word32 [b1; b2; b3; b4])`;

val bytes_def = Define`
  (bytes (w, 4) = [(7 >< 0) w; (15 >< 8) w; (23 >< 16) w; (31 >< 24) w]) /\
  (bytes (w, 2) = [(7 >< 0) w; (15 >< 8) w]) /\
  (bytes (w, 1) = [w2w (w:word32)] : word8 list)`;

val LSL_C_def = with_flag (computeLib.auto_import_definitions,false) Define`
  LSL_C (x: 'a word, shift:num) =
    if shift = 0 then
      ARB
    else
      let extended_x = w2n x * (2 ** shift) in
        (x << shift, BIT (dimindex(:'a)) extended_x)`;

val LSR_C_def = with_flag (computeLib.auto_import_definitions,false) Define`
  LSR_C (x: 'a word, shift:num) =
    if shift = 0 then
      ARB
    else
      (x >>> shift, BIT (shift - 1) (w2n x))`;

val ASR_C_def = with_flag (computeLib.auto_import_definitions,false) Define`
  ASR_C (x: 'a word, shift:num) =
    if shift = 0 then
      ARB
    else
      (x >> shift, x ' (MIN (dimindex(:'a) - 1) (shift - 1)))`;

val ROR_C_def = with_flag (computeLib.auto_import_definitions,false) Define`
  ROR_C (x: 'a word, shift:num) =
    if shift = 0 then
      ARB
    else let result = x #>> shift in
      (result, result ' (dimindex(:'a) - 1))`;

val RRX_C_def = Define`
  RRX_C (x: 'a word, carry_in:bool) =
    let (carry_out,result) = word_rrx(carry_in,x) in
      (result,carry_out)`;

val LSL_def = Define `LSL (x: 'a word, shift:num) = x << shift`;
val LSR_def = Define `LSR (x: 'a word, shift:num) = x >>> shift`;
val ASR_def = Define `ASR (x: 'a word, shift:num) = x >> shift`;
val ROR_def = Define `ROR (x: 'a word, shift:num) = x #>> shift`;

val RRX_def = Define`
  RRX (x: 'a word, carry_in:bool) = SND (word_rrx (carry_in,x))`;

val ITAdvance_def = with_flag (computeLib.auto_import_definitions,false) Define`
  ITAdvance (IT:word8) =
    if (2 >< 0) IT = 0b000w:word3 then
      0b00000000w
    else
      ((7 '' 5) IT !! w2w (((4 >< 0) IT) : word5 << 1))`;

val ITAdvance_n2w = save_thm("ITAdvance_n2w",
   ITAdvance_def
     |> SIMP_RULE (srw_ss()++wordsLib.WORD_EXTRACT_ss) []
     |> Q.SPEC `n2w n`
     |> CONV_RULE (RHS_CONV EVAL)
     |> GEN_ALL);

val decode_psr_def = Define`
  decode_psr (psr:word32) =
    <| N := psr ' 31;
       Z := psr ' 30;
       C := psr ' 29;
       V := psr ' 28;
       Q := psr ' 27;
       IT := (( 15 >< 10 ) psr : word6) @@ (( 26 >< 25 ) psr : word2);
       J := psr ' 24;
       Reserved := ( 23 >< 20 ) psr;
       GE := ( 19 >< 16 ) psr;
       E := psr ' 9;
       A := psr ' 8;
       I := psr ' 7;
       F := psr ' 6;
       T := psr ' 5;
       M := ( 4 >< 0 ) psr |>`;

val encode_psr_def = Define`
  encode_psr (psr:ARMpsr) : word32 =
    word_modify (\x b.
      if x < 5 then psr.M ' x else
      if x = 5 then psr.T else
      if x = 6 then psr.F else
      if x = 7 then psr.I else
      if x = 8 then psr.A else
      if x = 9 then psr.E else
      if x < 16 then psr.IT ' (x - 8) else
      if x < 20 then psr.GE ' (x - 16) else
      if x < 24 then psr.Reserved ' (x - 20) else
      if x = 24 then psr.J else
      if x < 27 then psr.IT ' (x - 25) else
      if x = 27 then psr.Q else
      if x = 28 then psr.V else
      if x = 29 then psr.C else
      if x = 30 then psr.Z else
      (* x = 31 *)   psr.N) 0w`;

val version_number_def = Define`
  (version_number ARMv4   = 4) /\
  (version_number ARMv4T  = 4) /\
  (version_number ARMv5T  = 5) /\
  (version_number ARMv5TE = 5) /\
  (version_number ARMv6   = 6) /\
  (version_number ARMv6K  = 6) /\
  (version_number ARMv6T2 = 6) /\
  (version_number ARMv7_A = 7) /\
  (version_number ARMv7_R = 7) /\
  (version_number ARMv7_M = 7)`;

val thumb2_support_def = Define`
  thumb2_support = {a | (a = ARMv6T2) \/ version_number a >= 7}`;

val _ = computeLib.auto_import_definitions := false;

val _ = set_fixity "=+>" (Infix(NONASSOC, 320));
val _ = set_fixity "=+<" (Infix(NONASSOC, 320));

(* Used when sorting applications of UPDATE *)

val Ua_def = xDefine "Ua" `$=+> = $=+`;
val Ub_def = xDefine "Ub" `$=+< = $=+`;

(* ------------------------------------------------------------------------ *)

infix \\ <<

val op \\ = op THEN;
val op << = op THENL;

val SUC_RULE = CONV_RULE numLib.SUC_TO_NUMERAL_DEFN_CONV;

val rule =
  SUC_RULE o GEN_ALL o
  SIMP_RULE arith_ss
    [GSYM bitTheory.TIMES_2EXP_def, MOD_2EXP_DIMINDEX, w2n_n2w] o
  Q.SPECL [`n2w n`,`SUC sh`];

val NUMERIC_LSL_C = save_thm("NUMERIC_LSL_C", rule LSL_C_def);
val NUMERIC_LSR_C = save_thm("NUMERIC_LSR_C", rule LSR_C_def);
val NUMERIC_ASR_C = save_thm("NUMERIC_ASR_C", rule ASR_C_def);
val NUMERIC_ROR_C = save_thm("NUMERIC_ROR_C", rule ROR_C_def);

local
  val rule = GEN_ALL o SIMP_RULE (srw_ss()) [] o Q.SPEC `n2w a`
in
  val align_n2w   = save_thm("align_n2w",   rule align_def)
  val aligned_n2w = save_thm("aligned_n2w", rule aligned_def)
end;

val align_slice = Q.store_thm("align_slice",
  `!n a:'a word. align (a,2 ** n) = (dimindex(:'a) - 1 '' n) a`,
  STRIP_TAC \\ Cases
    \\ SRW_TAC [ARITH_ss] [align_def, word_slice_n2w, SLICE_THM, BITS_THM2,
         DECIDE ``0 < n ==> (SUC (n - 1) = n)``]
    \\ FULL_SIMP_TAC (srw_ss()) [dimword_def]);

val MIN_LEM = Q.prove(`!a b. MIN a (MIN a b) = MIN a b`, SRW_TAC [] [MIN_DEF]);

val align_id = Q.store_thm("align_id",
  `!n a. align (align (a,2 ** n),2 ** n) = align (a,2 ** n)`,
  SRW_TAC [ARITH_ss,wordsLib.WORD_EXTRACT_ss]
          [DIMINDEX_GT_0,MIN_LEM,align_slice]
    \\ SRW_TAC [ARITH_ss] [MIN_DEF]
    \\ `n = 0` by DECIDE_TAC \\ SRW_TAC [] []);

val align_id_248 = save_thm("align_id_248",
  numLib.REDUCE_RULE
    (LIST_CONJ (map (fn t => Q.SPEC t align_id) [`1`,`2`,`3`])));

val word_index = Q.prove(
  `!i n. i < dimindex (:'a) ==> ((n2w n : 'a word) ' i = BIT i n)`,
  ONCE_REWRITE_TAC [word_index_n2w] \\ SRW_TAC [] []);

val BIT_EXISTS = METIS_PROVE [BIT_LOG2] ``!n. ~(n = 0) ==> ?b. BIT b n``;

val LEAST_BIT_INTRO =
 (SIMP_RULE (srw_ss()) [] o Q.SPEC `\i. BIT i n`)  whileTheory.LEAST_INTRO;

val LOWEST_SET_BIT_ELIM =
  (SIMP_RULE (srw_ss()) [AND_IMP_INTRO] o
   SIMP_RULE (srw_ss()) [BIT_EXISTS] o Q.DISCH `~(n = 0)` o
   Q.SPECL [`\x. x < dimindex (:'a)`,`\i. BIT i n`]) whileTheory.LEAST_ELIM;

val LOWEST_SET_BIT_LESS_LEAST =
  (SIMP_RULE (srw_ss()) [] o Q.SPEC `\i. BIT i n`) whileTheory.LESS_LEAST;

val LOWEST_SET_BIT_LT_DIMINDEX = Q.prove(
  `!n. ~(n = 0) /\ n < dimword(:'a) ==> (LEAST i. BIT i n) < dimindex(:'a)`,
  SRW_TAC [] [dimword_def]
    \\ MATCH_MP_TAC LOWEST_SET_BIT_ELIM
    \\ SRW_TAC [] []
    \\ SPOSE_NOT_THEN STRIP_ASSUME_TAC
    \\ FULL_SIMP_TAC std_ss [NOT_LESS]
    \\ IMP_RES_TAC TWOEXP_MONO2
    \\ `n < 2 ** n'` by DECIDE_TAC
    \\ METIS_TAC [NOT_BIT_GT_TWOEXP]);

val lowest_set_bit_compute = Q.store_thm("lowest_set_bit_compute",
  `!w. lowest_set_bit (w:'a word) =
       if w = 0w then
         dimindex(:'a)
       else
         LOWEST_SET_BIT (w2n w)`,
  Cases \\ SRW_TAC [] [lowest_set_bit_def, LOWEST_SET_BIT_def]
    \\ MATCH_MP_TAC LEAST_THM
    \\ SRW_TAC [] []
    \\ IMP_RES_TAC LOWEST_SET_BIT_LT_DIMINDEX
    \\ FULL_SIMP_TAC (srw_ss()++ARITH_ss)
         [word_index, LOWEST_SET_BIT_LESS_LEAST]
    \\ MATCH_MP_TAC LEAST_BIT_INTRO
    \\ METIS_TAC [BIT_EXISTS]);

val UPDATE_SORT_RULE1 = Q.store_thm("UPDATE_SORT_RULE1",
  `!R m a b d e. (!x y. R x y ==> ~(x = y)) ==>
     ((a =+> e) ((b =+> d) m) =
         if R a b then
           (b =+< d) ((a =+> e) m)
         else
           (a =+< e) ((b =+> d) m))`,
  METIS_TAC [Ua_def,Ub_def,combinTheory.UPDATE_COMMUTES]);

val UPDATE_SORT_RULE2 = Q.store_thm("UPDATE_SORT_RULE2",
  `!R m a b d e. (!x y. R x y ==> ~(x = y)) ==>
     ((a =+> e) ((b =+< d) m) =
         if R a b then
           (b =+< d) ((a =+> e) m)
         else
           (a =+< e) ((b =+< d) m))`,
  METIS_TAC [Ua_def,Ub_def,combinTheory.UPDATE_COMMUTES]);

val UPDATE_EQ_RULE = Q.store_thm("UPDATE_EQ_RULE",
  `((a =+< e) ((a =+> d) m) = (a =+> e) m) /\
   ((a =+< e) ((a =+< d) m) = (a =+< e) m) /\
   ((a =+> e) ((a =+> d) m) = (a =+> e) m)`,
  REWRITE_TAC [Ua_def,Ub_def,combinTheory.UPDATE_EQ]);

val NOT_IN_EMPTY_SPECIFICATION = save_thm("NOT_IN_EMPTY_SPECIFICATION",
  (GSYM o SIMP_RULE (srw_ss()) [] o Q.SPEC `{}`) pred_setTheory.SPECIFICATION);

val _ = computeLib.add_persistent_funs
  [("pairTheory.UNCURRY",         pairTheory.UNCURRY),
   ("pairTheory.LEX_DEF",         pairTheory.LEX_DEF),
   ("pred_setTheory.IN_CROSS",    pred_setTheory.IN_CROSS),
   ("pred_setTheory.IN_DELETE",   pred_setTheory.IN_DELETE),
   ("wordsTheory.BIT_UPDATE",     wordsTheory.BIT_UPDATE),
   ("NOT_IN_EMPTY_SPECIFICATION", NOT_IN_EMPTY_SPECIFICATION),
   ("NUMERIC_LSL_C",              NUMERIC_LSL_C),
   ("NUMERIC_LSR_C",              NUMERIC_LSR_C),
   ("NUMERIC_ASR_C",              NUMERIC_ASR_C),
   ("NUMERIC_ROR_C",              NUMERIC_ROR_C),
   ("align_n2w",                  align_n2w),
   ("aligned_n2w",                aligned_n2w),
   ("align_id_248",               align_id_248),
   ("lowest_set_bit_compute",     lowest_set_bit_compute),
   ("ITAdvance_n2w",              ITAdvance_n2w),
   ("RName_EQ_RName",             theorem "RName_EQ_RName"),
   ("RName2num_thm",              theorem "RName2num_thm"),
   ("num2RName_thm",              theorem "num2RName_thm"),
   ("PSRName_EQ_PSRName",         theorem "PSRName_EQ_PSRName"),
   ("PSRName2num_thm",            theorem "PSRName2num_thm"),
   ("num2PSRName_thm",            theorem "num2PSRName_thm"),
   ("ARMarch_EQ_ARMarch",         theorem "ARMarch_EQ_ARMarch"),
   ("ARMarch2num_thm",            theorem "ARMarch2num_thm"),
   ("num2ARMarch_thm",            theorem "num2ARMarch_thm"),
   ("SRType_EQ_SRType",           theorem "SRType_EQ_SRType"),
   ("SRType2num_thm",             theorem "SRType2num_thm"),
   ("num2SRType_thm",             theorem "num2SRType_thm"),
   ("InstrSet_EQ_InstrSet",       theorem "InstrSet_EQ_InstrSet"),
   ("InstrSet2num_thm",           theorem "InstrSet2num_thm"),
   ("num2InstrSet_thm",           theorem "num2InstrSet_thm"),
   ("Encoding_EQ_Encoding",       theorem "Encoding_EQ_Encoding"),
   ("Encoding2num_thm",           theorem "Encoding2num_thm"),
   ("num2Encoding_thm",           theorem "num2Encoding_thm")];

val _ = export_theory ();
