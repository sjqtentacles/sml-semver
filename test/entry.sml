(* entry.sml -- runs every suite and exits with a status code. *)

fun runAllSuites () =
  ( Harness.reset ()
  ; ParseTests.run ()
  ; CompareTests.run ()
  ; RangeTests.run ()
  ; PropertyTests.run ()
  ; Harness.run () )

fun main () =
  OS.Process.exit
    (if runAllSuites () then OS.Process.success else OS.Process.failure)
