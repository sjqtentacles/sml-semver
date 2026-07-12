(* test_properties.sml -- sml-check property-based tests for Semver
   parse/toString round-tripping and compare's ordering laws. *)

structure PropertyTests =
struct
  open Support

  (* A generator of well-formed version records (bypassing free-form string
     generation: constructing a valid record and rendering it with S.toString
     guarantees the printed string is grammatically valid SemVer). Numeric
     core parts stay small and non-negative (Int.toString never produces a
     leading zero for values >= 0 except "0" itself, which is legal).
     Prerelease/build identifiers are kept ALPHABETIC-first (never purely
     numeric) to sidestep the spec's "no leading zero on numeric identifiers"
     rule entirely. *)

  val numPart = Check.choose (0, 50)

  (* identifier: a letter, followed by 0-3 alnum chars *)
  val identGen =
    Check.bind (Check.charRange (#"a", #"z")) (fn c0 =>
      Check.bind (Check.listOfLen 3 (Check.elements (String.explode "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")))
        (fn cs => Check.pure (String.implode (c0 :: cs))))

  val versionGen : Semver.version Check.gen =
    Check.bind numPart (fn ma =>
    Check.bind numPart (fn mi =>
    Check.bind numPart (fn pa =>
    Check.bind (Check.listOf identGen) (fn pre =>
    Check.bind (Check.listOf identGen) (fn bld =>
      Check.pure { major = ma, minor = mi, patch = pa
                 , prerelease = pre, build = bld })))))

  fun run () =
    ( Harness.section "SemVer: properties (sml-check)"

    ; Harness.check "prop: parse (toString v) round-trips (via S.eq)"
        (case Check.quickCheck
                (Check.forAll versionGen S.toString
                   (fn v => case S.parse (S.toString v) of
                                SOME v' => S.eq (v, v')
                              | NONE    => false)) of
             Check.Passed _ => true
           | Check.Failed _ => false)

    ; Harness.check "prop: compare is antisymmetric (a<b iff b>a, a=b iff b=a)"
        (case Check.quickCheck
                (Check.forAll
                   (Check.tuple2 (versionGen, versionGen))
                   (fn (a, b) => S.toString a ^ " vs " ^ S.toString b)
                   (fn (a, b) =>
                      case (S.compare (a, b), S.compare (b, a)) of
                          (GREATER, LESS)  => true
                        | (LESS, GREATER)  => true
                        | (EQUAL, EQUAL)   => true
                        | _                => false)) of
             Check.Passed _ => true
           | Check.Failed _ => false)
    )
end
