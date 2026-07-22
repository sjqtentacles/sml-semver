# sml-semver

[![CI](https://github.com/sjqtentacles/sml-semver/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-semver/actions/workflows/ci.yml)

[Semantic Versioning 2.0.0](https://semver.org) in pure Standard ML: version
parsing, precedence comparison (spec §11), and npm/[node-semver](https://github.com/npm/node-semver)-style
range/constraint matching (`^`, `~`, `>=`, `>`, `<`, `<=`, `=`, `x`/`*`
wildcards, hyphen ranges, and `||` unions). Parsing is built on the vendored
[`sml-parsec`](https://github.com/sjqtentacles/sml-parsec) `CharParsec`
combinators. No FFI, no external dependencies, and **deterministic**,
byte-identically under both [MLton](http://mlton.org/) and
[Poly/ML](https://www.polyml.org/).

## Status

- 169 assertions, green on MLton and Poly/ML with byte-identical output.
- Basis-library only; deterministic across compilers.
- Numeric version fields are bounded to the portable signed-32-bit range and
  rejected gracefully beyond it, so an oversized version parses identically on
  both compilers instead of raising `Overflow` under MLton's fixed-width `int`.
- Vendors `sml-parsec` (Layout B), so the repo builds standalone.
- Validated against canonical vectors:
  - The SemVer spec §11 precedence chain
    `1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0`.
  - node-semver caret/tilde/x-range/hyphen/union truth tables (`^1.2.3`,
    `^0.2.3`, `^0.0.3`, `~1.2`, `1.x`, `1.2.3 - 2.3.4`, `a || b`, …).
  - Build-metadata-ignored precedence (`1.0.0+a` = `1.0.0+b` = `1.0.0`).
  - Invalid-string rejection and `toString o parse` round-trips.

## Install

With [`smlpkg`](https://github.com/diku-dk/smlpkg):

```
smlpkg add github.com/sjqtentacles/sml-semver
smlpkg sync
```

Include the MLB from your own (it pulls in the vendored `sml-parsec`):

```
local
  $(SML_LIB)/basis/basis.mlb
  lib/github.com/sjqtentacles/sml-semver/... (via smlpkg)
in
  ...
end
```

This brings `structure Semver` (and the vendored `CharParsec`) into scope.

## Quick start

```sml
(* parse + render *)
val v = Semver.parseExn "1.2.3-beta.2+build.7"
val s = Semver.toString v                       (* "1.2.3-beta.2+build.7" *)

(* precedence (spec §11); build metadata is ignored *)
val ord = Semver.compare (Semver.parseExn "1.0.0-alpha", Semver.parseExn "1.0.0")
(* LESS — a prerelease has lower precedence than the release *)
val same = Semver.eq (Semver.parseExn "1.0.0+a", Semver.parseExn "1.0.0+b")
(* true — build metadata does not affect precedence *)

(* range matching, node-semver semantics *)
val r  = Semver.parseRangeExn "^1.2.3"          (* >=1.2.3 <2.0.0 *)
val ok = Semver.satisfies (Semver.parseExn "1.9.9", r)   (* true  *)
val no = Semver.satisfies (Semver.parseExn "2.0.0", r)   (* false *)

(* pick the highest matching version *)
val pool = List.map Semver.parseExn ["1.2.0", "1.2.3", "1.9.9", "2.0.0"]
val best = Semver.maxSatisfying (pool, r)       (* SOME 1.9.9 *)
```

## Demo

`make example` runs [`examples/demo.sml`](examples/demo.sml):

```
sml-semver demo
===============
parsed          : 1.2.3-beta.2+build.7
  major/minor/patch = 1/2/3
  prerelease        = beta.2
  build             = build.7

precedence (sorted ascending, spec 11):
  1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0

range ^1.2.3:
  1.2.3  -> true
  1.5.0  -> true
  2.0.0  -> false

range ~1.2.3:
  1.2.3  -> true
  1.2.9  -> true
  1.3.0  -> false

range 1.2.3 - 2.3.4:
  1.2.2  -> false
  2.0.0  -> true
  2.3.5  -> false

range >=1.0.0 <2.0.0 || >=3.0.0:
  1.5.0  -> true
  2.5.0  -> false
  3.1.0  -> true

maxSatisfying ^1.2.3 over {1.2.0,1.2.3,1.9.9,2.0.0,0.9.0} = 1.9.9
```

## API

```sml
type version =
  { major : int, minor : int, patch : int
  , prerelease : string list, build : string list }

exception Semver of string

val parse         : string -> version option
val parseExn      : string -> version
val toString      : version -> string

val compare       : version * version -> order   (* spec §11; build ignored *)
val eq  : version * version -> bool
val lt  : version * version -> bool
val gt  : version * version -> bool
val lte : version * version -> bool
val gte : version * version -> bool

type range
val parseRange    : string -> range option
val parseRangeExn : string -> range
val satisfies     : version * range -> bool
val maxSatisfying : version list * range -> version option
```

| Function | Behavior |
| --- | --- |
| `parse s` | strict SemVer 2.0.0 parse (a leading `v` is tolerated); `NONE` on malformed input |
| `toString v` | canonical `major.minor.patch[-prerelease][+build]` rendering |
| `compare (a, b)` | precedence per spec §11: numeric core numerically, prerelease identifiers numeric-vs-alphanumeric (numeric ranks lower), prerelease < release, build metadata **ignored** |
| `parseRange s` | parse a node-semver range string; `NONE` on malformed input |
| `satisfies (v, r)` | `true` iff `v` matches `r` (a prerelease version only matches a comparator set that pins a prerelease at the same `major.minor.patch`) |
| `maxSatisfying (vs, r)` | the highest (by `compare`) version in `vs` that satisfies `r`, or `NONE` |

### Supported range syntax

| Form | Expansion |
| --- | --- |
| `^1.2.3` | `>=1.2.3 <2.0.0` |
| `^0.2.3` | `>=0.2.3 <0.3.0` |
| `^0.0.3` | `>=0.0.3 <0.0.4` |
| `^1.2` / `^1` | `>=1.2.0 <2.0.0` / `>=1.0.0 <2.0.0` |
| `~1.2.3` | `>=1.2.3 <1.3.0` |
| `~1.2` / `~1` | `>=1.2.0 <1.3.0` / `>=1.0.0 <2.0.0` |
| `1.x` / `1.2.*` | `>=1.0.0 <2.0.0` / `>=1.2.0 <1.3.0` |
| `*` / `` (empty) | any release |
| `1.2.3 - 2.3.4` | `>=1.2.3 <=2.3.4` |
| `1.2.3 - 2.3` | `>=1.2.3 <2.4.0` |
| `>=1.0.0 <2.0.0` | space-separated intersection (all must hold) |
| `a \|\| b` | union (either side may hold) |

### Conventions

- **Strict core, lenient sugar.** `parse` enforces SemVer 2.0.0 strictly
  (three numeric identifiers, no leading zeros, dot-separated
  prerelease/build identifiers from `[0-9A-Za-z-]`), tolerating only an
  optional leading `v`. Range descriptors additionally accept partial
  versions and `x`/`X`/`*` wildcards.
- **Build metadata is ignored for precedence**, exactly as the spec requires;
  it is preserved by `parse`/`toString` for round-tripping.
- **node-semver prerelease rule.** With the default (non-`includePrerelease`)
  semantics, a version carrying a prerelease only satisfies a comparator set
  that itself pins a prerelease at the same `major.minor.patch`, so
  `1.2.3-beta` does **not** satisfy `>=1.0.0`.

## Build & test

```
make test        # MLton
make test-poly   # Poly/ML
make all-tests   # both
make example     # build + run examples/demo.sml
make clean
```

## License

MIT — see [LICENSE](LICENSE).
