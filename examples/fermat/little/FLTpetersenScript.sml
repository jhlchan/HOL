(* ------------------------------------------------------------------------- *)
(* Fermat's Little Theorem - Necklace proof of Julius Petersen.              *)
(* ------------------------------------------------------------------------- *)

(*

Fermat's Little Theorem (Combinatorial proof)
=============================================
Solomon W. Golomb (1956)
http://www.cimat.mx/~mmoreno/teaching/spring08/Fermats_Little_Thm.pdf

Original proof by J. Petersen in 1872:

Take p elements from q with repetitions in all ways, that is, in q^p ways.
The q sets with elements all alike are not changed by a cyclic permutation of the elements,
while the remaining q^p - q sets are permuted in sets of p. Hence p divides q^p - q.

This is a combinatorial using Group action, via Orbit-Stabilizer Theorem.

*)

(*===========================================================================*)

(*===========================================================================*)

(* add all dependent libraries for script *)
open HolKernel boolLib bossLib Parse;

(* declare new theory at start *)
val _ = new_theory "FLTpetersen";

(* ------------------------------------------------------------------------- *)


(* open dependent theories *)
(* val _ = load "FLTactionTheory"; *)
open helperNumTheory helperSetTheory;
open arithmeticTheory pred_setTheory;
open dividesTheory; (* for PRIME_POS *)

open necklaceTheory; (* for multicoloured_finite *)

open groupTheory;
open groupActionTheory;


(* ------------------------------------------------------------------------- *)
(* Fermat's Little Theorem by Action Documentation                           *)
(* ------------------------------------------------------------------------- *)
(* Overloading:
*)
(*

   From groupInstances:
   Zadd_group          |- !n. 0 < n ==> Group (Zadd n)

   From FLTnecklace:
   necklace_cycle      |- !n a ls k. ls IN necklace n a ==> cycle k ls IN necklace n a
   multicoloured_cycle |- !n a ls k. ls IN multicoloured n a ==> cycle k ls IN multicoloured n a
   multicoloured_not_cycle_1
                       |- !n a ls. ls IN multicoloured n a ==> cycle 1 ls <> ls

   From FLTaction:
   cycle_action_on_multicoloured
                       |- !n a. 0 < n ==> (Zadd n act multicoloured n a) cycle
   multicoloured_orbit_not_sing
                       |- !n a ls. ls IN multicoloured n a ==>
                                   ~SING (orbit cycle (Zadd n) (multicoloured n a) ls)
   multicoloured_orbit_card_not_1
                       |- !n a ls. ls IN multicoloured n a ==>
                                   CARD (orbit cycle (Zadd n) (multicoloured n a) ls) <> 1
   multicoloured_orbit_card_prime
                       |- !p a ls. prime p /\ ls IN multicoloured p a ==>
                                   CARD (orbit cycle (Zadd p) (multicoloured p a) ls) = p

   Application:
   Fermat_Little_Theorem   |- !p a. prime p ==> p divides a ** p - a

*)

(* ------------------------------------------------------------------------- *)
(* Note: This is a self-contained proof following Petersen's style.          *)
(* ------------------------------------------------------------------------- *)

(* ------------------------------------------------------------------------- *)
(* Combinatorial Proof via Group action.                                     *)
(* ------------------------------------------------------------------------- *)

(* Part 1: Basic ----------------------------------------------------------- *)

val Zadd_group = groupInstancesTheory.Zadd_group;
(* |- !n. 0 < n ==> Group (Zadd n) *)

val necklace_cycle = FLTnecklaceTheory.necklace_cycle;
(* |- !n a ls k. ls IN necklace n a ==> cycle k ls IN necklace n a *)

val multicoloured_cycle = FLTnecklaceTheory.multicoloured_cycle;
(* |- !n a ls k. ls IN multicoloured n a ==> cycle k ls IN multicoloured n a *)

val multicoloured_not_cycle_1 = FLTnecklaceTheory.multicoloured_not_cycle_1;
(* |- !n a ls. ls IN multicoloured n a ==> cycle 1 ls <> ls *)

(* Part 2: Action ---------------------------------------------------------- *)

val cycle_action_on_multicoloured = FLTactionTheory.cycle_action_on_multicoloured;
(* |- !n a. 0 < n ==> (Zadd n act multicoloured n a) cycle *)

val multicoloured_orbit_not_sing = FLTactionTheory.multicoloured_orbit_not_sing;
(* |- !n a ls. ls IN multicoloured n a ==>
               ~SING (orbit cycle (Zadd n) (multicoloured n a) ls) *)

val multicoloured_orbit_card_not_1 = FLTactionTheory.multicoloured_orbit_card_not_1;
(* |- !n a ls. ls IN multicoloured n a ==>
               CARD (orbit cycle (Zadd n) (multicoloured n a) ls) <> 1 *)

val multicoloured_orbit_card_prime = FLTactionTheory.multicoloured_orbit_card_prime;
(* |- !p a ls. prime p /\ ls IN multicoloured p a ==>
              CARD (orbit cycle (Zadd p) (multicoloured p a) ls) = p *)

(* Part 3: Application ----------------------------------------------------- *)

(* Idea: [Fermat's Little Theorem] -- line by line
         !p a. prime p ==> p divides (a ** p - a)   *)
(* Proof (J. Petersen in 1872):
   Take p elements from a with repetitions in all ways, that is, in a^p ways.
                   by necklace_card
   The a sets with elements all alike are not changed by a cyclic permutation of the elements,
                   by monocoloured_card
   while the remaining (a^p - a) sets are
                   by multicoloured_card
   permuted in sets of p.
                   by cycle_action_on_multicoloured, multicoloured_orbit_card_prime
   Hence p divides a^p - a.
                   by orbits_equal_size_property
*)

(* Theorem: prime p ==> p divides (a ** p - a) *)
(* Proof:
   Let A = multicoloured p a,
       b = (\ls. orbit cycle (Zadd p) ls).
   Note 0 < p                      by PRIME_POS
    and FINITE A                   by multicoloured_finite
   with CARD A = a ** p - a        by multicoloured_card, 0 < p
   Also Group (Zadd p)             by Zadd_group, 0 < p
   with (Zadd p act A) cycle       by cycle_action_on_multicoloured, 0 < p
   then !ls. ls IN A ==> CARD (b ls) = p
                                   by multicoloured_orbit_card_prime
   thus p divides CARD A           by orbits_equal_size_property
     or p divides (a ** p - a)     by above

orbits_equal_size_property |> ISPEC ``cycle`` |> ISPEC ``Zadd p``;
|- !A n. Group (Zadd p) /\ (Zadd p act A) cycle /\ FINITE A /\
         (!x. x IN A ==> CARD (orbit cycle (Zadd p) A x) = n) ==> n divides CARD A
*)
Theorem Fermat_Little_Theorem:
  !p a. prime p ==> p divides (a ** p - a)
Proof
  rpt strip_tac >>
  (* prime p is positive *)
  `0 < p` by rw[PRIME_POS] >>
  (* let A = the set of multicoloured necklaces *)
  qabbrev_tac `A = multicoloured p a` >>
  (* set A is finite *)
  `FINITE A` by rw[multicoloured_finite, Abbr`A`] >>
  (* and cardinality of A is known *)
  `CARD A = a ** p - a` by rw[multicoloured_card, Abbr`A`] >>
  (* Modulo p is an additive group, by 0 < p *)
  `Group (Zadd p)` by rw[Zadd_group] >>
  (* and acts on A by cycle *)
  `(Zadd p act A) cycle` by rw[cycle_action_on_multicoloured, Abbr`A`] >>
  (* then all orbits of multicoloured necklaces has size = p *)
  imp_res_tac multicoloured_orbit_card_prime >>
  (* therefore prime p divides the cardinality of A *)
  metis_tac[orbits_equal_size_property]
QED


(* Part 4: End ------------------------------------------------------------- *)

(* ------------------------------------------------------------------------- *)

(* export theory at end *)
val _ = export_theory();

(*===========================================================================*)
