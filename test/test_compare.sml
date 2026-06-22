(* test_compare.sml -- precedence per SemVer spec section 11. *)

structure CompareTests =
struct
  open Support

  fun cmp (a, b) = S.compare (parseExn a, parseExn b)

  (* every adjacent pair in the spec chain is strictly increasing, and the
     relation is transitive across the whole chain. *)
  fun allPairsIncreasing [] = ()
    | allPairsIncreasing (x :: rest) =
        ( List.app
            (fn y =>
               Harness.checkString (x ^ " < " ^ y)
                 ("LESS", orderToString (cmp (x, y))))
            rest
        ; allPairsIncreasing rest )

  fun run () =
    ( Harness.section "compare: spec 11 precedence chain (all increasing pairs)"
    ; allPairsIncreasing precedenceChain

    ; Harness.section "compare: numeric core compared numerically"
    ; Harness.checkString "2.0.0 > 1.9.9"  ("GREATER", orderToString (cmp ("2.0.0", "1.9.9")))
    ; Harness.checkString "1.10.0 > 1.9.0" ("GREATER", orderToString (cmp ("1.10.0", "1.9.0")))
    ; Harness.checkString "1.0.10 > 1.0.9" ("GREATER", orderToString (cmp ("1.0.10", "1.0.9")))

    ; Harness.section "compare: prerelease < release"
    ; Harness.checkString "1.0.0-alpha < 1.0.0" ("LESS", orderToString (cmp ("1.0.0-alpha", "1.0.0")))

    ; Harness.section "compare: numeric prerelease id < alphanumeric id"
    ; Harness.checkString "1.0.0-1 < 1.0.0-alpha" ("LESS", orderToString (cmp ("1.0.0-1", "1.0.0-alpha")))
    ; Harness.checkString "1.0.0-alpha.1 < 1.0.0-alpha.beta" ("LESS", orderToString (cmp ("1.0.0-alpha.1", "1.0.0-alpha.beta")))

    ; Harness.section "compare: larger prerelease set wins when prefix equal"
    ; Harness.checkString "1.0.0-alpha < 1.0.0-alpha.1" ("LESS", orderToString (cmp ("1.0.0-alpha", "1.0.0-alpha.1")))

    ; Harness.section "compare: build metadata IGNORED for precedence"
    ; Harness.checkString "1.0.0+a = 1.0.0+b"     ("EQUAL", orderToString (cmp ("1.0.0+a", "1.0.0+b")))
    ; Harness.checkString "1.0.0 = 1.0.0+build"   ("EQUAL", orderToString (cmp ("1.0.0", "1.0.0+build")))
    ; Harness.checkString "1.0.0-beta+1 = 1.0.0-beta+2" ("EQUAL", orderToString (cmp ("1.0.0-beta+1", "1.0.0-beta+2")))

    ; Harness.section "compare: derived predicates"
    ; Harness.checkBool "eq 1.2.3 1.2.3+x"  (true,  S.eq  (parseExn "1.2.3", parseExn "1.2.3+x"))
    ; Harness.checkBool "lt 1.2.3 1.2.4"    (true,  S.lt  (parseExn "1.2.3", parseExn "1.2.4"))
    ; Harness.checkBool "gt 2.0.0 1.9.9"    (true,  S.gt  (parseExn "2.0.0", parseExn "1.9.9"))
    ; Harness.checkBool "lte 1.2.3 1.2.3"   (true,  S.lte (parseExn "1.2.3", parseExn "1.2.3"))
    ; Harness.checkBool "gte 1.2.3 1.2.3"   (true,  S.gte (parseExn "1.2.3", parseExn "1.2.3"))
    ; Harness.checkBool "not gt 1.2.3 1.2.3" (false, S.gt (parseExn "1.2.3", parseExn "1.2.3")) )
end
