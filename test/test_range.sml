(* test_range.sml -- node-semver range / constraint matching. *)

structure RangeTests =
struct
  open Support

  fun sat (vstr, rstr) = S.satisfies (parseExn vstr, rangeExn rstr)

  fun run () =
    ( Harness.section "range: caret / tilde / x-range / hyphen / union truth tables"
    ; List.app
        (fn (rstr, yes, no) =>
           ( List.app
               (fn v =>
                  Harness.checkBool (v ^ " satisfies " ^ rstr) (true, sat (v, rstr)))
               yes
           ; List.app
               (fn v =>
                  Harness.checkBool (v ^ " !satisfies " ^ rstr) (false, sat (v, rstr)))
               no ))
        rangeTruth

    ; Harness.section "range: explicit caret boundaries"
    ; Harness.checkBool "^1.2.3 := >=1.2.3 <2.0.0 (1.2.3)" (true, sat ("1.2.3", "^1.2.3"))
    ; Harness.checkBool "^1.2.3 excludes 2.0.0"            (false, sat ("2.0.0", "^1.2.3"))
    ; Harness.checkBool "^0.0.3 excludes 0.0.4"            (false, sat ("0.0.4", "^0.0.3"))

    ; Harness.section "range: comparators"
    ; Harness.checkBool ">=1.0.0 (1.0.0)" (true,  sat ("1.0.0", ">=1.0.0"))
    ; Harness.checkBool ">1.0.0 (1.0.0)"  (false, sat ("1.0.0", ">1.0.0"))
    ; Harness.checkBool "<2.0.0 (1.9.9)"  (true,  sat ("1.9.9", "<2.0.0"))
    ; Harness.checkBool "<=1.2.3 (1.2.3)" (true,  sat ("1.2.3", "<=1.2.3"))
    ; Harness.checkBool "=1.2.3 (1.2.3)"  (true,  sat ("1.2.3", "=1.2.3"))
    ; Harness.checkBool "=1.2.3 (1.2.4)"  (false, sat ("1.2.4", "=1.2.3"))

    ; Harness.section "range: intersection requires all comparators"
    ; Harness.checkBool ">=1.0.0 <2.0.0 (1.5.0)" (true,  sat ("1.5.0", ">=1.0.0 <2.0.0"))
    ; Harness.checkBool ">=1.0.0 <2.0.0 (2.0.0)" (false, sat ("2.0.0", ">=1.0.0 <2.0.0"))

    ; Harness.section "range: prerelease only matches a pinned-prerelease set"
    ; Harness.checkBool "1.2.3-beta.1 !satisfies >=1.0.0" (false, sat ("1.2.3-beta.1", ">=1.0.0"))
    ; Harness.checkBool "1.2.3-beta.2 satisfies >=1.2.3-beta.1 <2.0.0"
        (true, sat ("1.2.3-beta.2", ">=1.2.3-beta.1 <2.0.0"))
    ; Harness.checkBool "1.2.4-beta.1 !satisfies >=1.2.3-beta.1 <2.0.0 (diff tuple)"
        (false, sat ("1.2.4-beta.1", ">=1.2.3-beta.1 <2.0.0"))
    ; Harness.checkBool "release 1.2.3 satisfies >=1.0.0" (true, sat ("1.2.3", ">=1.0.0"))

    ; Harness.section "range: caret with prerelease lower bound"
    ; Harness.checkBool "1.2.3-beta.3 satisfies ^1.2.3-beta.2" (true, sat ("1.2.3-beta.3", "^1.2.3-beta.2"))
    ; Harness.checkBool "1.2.3-beta.1 !satisfies ^1.2.3-beta.2" (false, sat ("1.2.3-beta.1", "^1.2.3-beta.2"))

    ; Harness.section "range: invalid range -> NONE"
    ; Harness.checkBool "reject \">=foo\"" (true, not (Option.isSome (S.parseRange ">=foo")))
    ; Harness.checkBool "reject \"1.2.3 -\"" (true, not (Option.isSome (S.parseRange "1.2.3 -")))

    ; Harness.section "maxSatisfying"
    ; let val vs = List.map parseExn ["1.2.0", "1.2.3", "1.9.9", "2.0.0", "0.9.0"]
      in Harness.checkString "max of ^1.2.3"
           ("1.9.9",
            case S.maxSatisfying (vs, rangeExn "^1.2.3") of
               SOME v => S.toString v | NONE => "NONE")
       ; Harness.checkString "max of >=3.0.0 (none)"
           ("NONE",
            case S.maxSatisfying (vs, rangeExn ">=3.0.0") of
               SOME v => S.toString v | NONE => "NONE")
      end )
end
