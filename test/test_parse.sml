(* test_parse.sml -- parsing valid/invalid strings and toString round-trips. *)

structure ParseTests =
struct
  open Support

  val validRoundTrip =
    [ "0.0.0"
    , "1.2.3"
    , "10.20.30"
    , "1.0.0-alpha"
    , "1.0.0-alpha.1"
    , "1.0.0-0.3.7"
    , "1.0.0-x.7.z.92"
    , "1.0.0-alpha+001"
    , "1.0.0+20130313144700"
    , "1.0.0-beta+exp.sha.5114f85"
    , "1.2.3----RC-SNAPSHOT.12.9.1--.12+788" ]

  val invalid =
    [ ""
    , "1"
    , "1.2"
    , "1.2.3.4"
    , "01.2.3"
    , "1.02.3"
    , "1.2.03"
    , "1.2.3-"
    , "1.2.3+"
    , "1.2.3-01"          (* numeric prerelease id with leading zero *)
    , "1.2.x"
    , "a.b.c"
    , "1.2.3-beta_1"      (* underscore not allowed in identifiers *)
    , "-1.2.3" ]

  fun run () =
    ( Harness.section "parse: valid round-trips (toString o parse)"
    ; List.app
        (fn s =>
           Harness.checkString ("round-trip " ^ s)
             (s, S.toString (parseExn s)))
        validRoundTrip

    ; Harness.section "parse: field extraction"
    ; let val v = parseExn "1.2.3-beta.2+build.7"
      in Harness.checkInt "major" (1, #major v)
       ; Harness.checkInt "minor" (2, #minor v)
       ; Harness.checkInt "patch" (3, #patch v)
       ; Harness.checkStringList "prerelease" (["beta", "2"], #prerelease v)
       ; Harness.checkStringList "build" (["build", "7"], #build v)
      end

    ; Harness.section "parse: leading v tolerated"
    ; Harness.checkString "v1.2.3" ("1.2.3", S.toString (parseExn "v1.2.3"))

    ; Harness.section "parse: invalid -> NONE"
    ; List.app
        (fn s =>
           Harness.checkBool ("reject \"" ^ s ^ "\"")
             (true, not (Option.isSome (S.parse s))))
        invalid

    ; Harness.section "parse: parseExn raises on invalid"
    ; Harness.checkRaises "parseExn \"nope\"" (fn () => S.parseExn "nope") )
end
