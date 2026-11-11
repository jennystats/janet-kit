# janet-kit

Three small modules for Janet utility scripting. Each helper exists because
the underlying Janet API has a behaviour that is easy to get wrong - the
helper is the workaround, written down so it does not have to be
rediscovered.

Part of [Jenny Stats](https://github.com/jennystats), a home for Janet
data and statistics packages. Jenny is just Janet.

| module                    | what                                                | API                          |
|---------------------------|-----------------------------------------------------|------------------------------|
| `jennystats/typed.janet` | runtime type guards for functions                   | `defn/typed` macro           |
| `jennystats/kit.janet`   | shell / path / file helpers that encode the gotchas | 11 functions                 |
| `jennystats/assert.janet` | error assertions for testament                     | 5 functions                  |

Core stdlib only. No native modules, no build step, no C toolchain.
Developed and tested on Janet 1.42.

## Quick start

All jenny modules install under a `jennystats/` namespace directory -
collision-proof against bare-name shadowing of core symbols or other
packages, by construction:

```janet
(import jennystats/kit :as kit)

(kit/sh "git status --short")
```

`(import jennystats/kit)` works the same with the `kit/` call
prefix; the `:as` form above is the one used in this repo's tests.

## typed - typed function definitions

```janet
(import jennystats/typed :prefix "")

(defn/typed half {:args [:number] :ret :number} [x] (/ x 2))

(half 4)   # -> 2
(half "x") # error: half: arg 0 expected :number, got string
```

- Type spec: `{:args [:string :number] :ret :string}`.
- Known types: `:nil :boolean :number :string :buffer :keyword :symbol
  :table :struct :array :tuple :function :fiber :bytes :any`.
- Docstring: place it after `[params]`, as a leading body string -
  `(defn/typed half {:args [:number] :ret :number} [x] "docstring" ...)`.
  A docstring between the spec and `[params]` does not compile
  (`spec is missing :args`).
- Arity mismatch between arglist and spec, unknown type keywords, a
  missing `:args` key and varargs (`& rest` arglists) are compile-time
  errors; `:ret` is optional (omit it, or pass nil, for no return check).
  Value guards run at call time.
- Guard predicates resolve at macro expansion, so a guard costs one direct
  predicate call - about 310ns per call with 3 argument guards on Janet
  1.42 (about 400ns with a return guard, versus about 40ns for an
  unguarded call).

### Alternatives

- **[deft](https://codeberg.org/zzkt/deft)** (zzkt) - the research end of
  the spectrum: a gradual type system with bidirectional inference and
  unification, blame calculus, compound types (union/intersection/ADTs),
  record types, higher-order contracts, per-argument gradual annotations,
  and optional static checking. For writing a typed application.
  `typed` (this module) is the minimal end: a guard macro for call
  boundaries - zero dependencies, ~310ns per call, compile-time arity
  checks. Different instruments, not rivals.

## kit - helpers that encode the gotchas

Each helper's docstring states the Janet behaviour it corrects. Summary:

- `sh cmd` - `os/execute` takes an argv tuple with no PATH lookup and
  rejects bare strings; every command routes through `/bin/sh`. Returns the
  exit code.
- `sh-capture cmd` - `os/spawn` has no readable pipe slots on any flag;
  stdout is captured via temp file. The file is unique per call, created
  with noclobber (a pre-existing entry is refused, so a pre-created
  symlink cannot clobber another file) and removed after reading, and the
  redirect covers the whole command. Returns trimmed stdout; a failing
  command captures `""` (use `sh` for the exit code); stderr passes
  through to the Janet process.
- `sh-quote s` / `sh-join parts` - rebuilding a shell command by
  space-joining argv re-splits paths containing spaces; re-quote. Double
  quotes neutralise spaces, quotes, backslashes, `$` and backticks, so
  hostile strings stay data; a NUL byte is rejected with its position
  (it cannot cross `execve`).
- `slurp-string path` - `slurp` returns a *buffer* and `=` is type-strict,
  so byte-identical contents still compare unequal; this returns a string.
- `script-args` - `(dyn *args*)` includes the script path at index 0; this
  returns only the user-supplied arguments as a tuple.
- `home-dir` - `HOME` from the environment, with a clear error when unset.
- `realpath p` - symlink resolution via `realpath -m` (tolerates
  non-existent paths). Needed because `*args*` element 0 is the *invoked*
  path, not the real script - derive repo locations from this.
- `dirname p` - everything before the last `/` (`.` when none, `/` for a
  root child).
- `path-exists p` - `os/stat` returns nil for missing paths (it does not
  throw), so a naive `try`-based existence check is vacuously true for
  every path; this checks the result.
- `dbl x` - Janet's core numbers are doubles, but `int/s64`/`int/u64`
  wrappers are their own types: they print like plain numbers, compare
  unequal (`(= (int/s64 5) 5)` is false) and survive `(+ 0.0 x)`
  unwrapped. This unwraps them. Related trap: `/` is division on
  doubles, so `(* 330 (/ 7 5))` lands one ulp below 462 - it *prints*
  `462` yet `(= v 462)` is false; near-integer counts need `math/round`.

### Alternatives

- **[janet-sh](https://github.com/andrewchambers/janet-sh)** - a shell
  DSL: `(sh/$ cat ,path | sort | uniq)` with interpolation, pipelines and
  capture forms. It is a syntax layer for writing shell lines; this module
  is a set of primitives for building them safely from Janet values -
  quoting, argv boundaries, exit codes.
- **[janet-process](https://github.com/andrewchambers/janet-process)** -
  child-process supervision: spawn with redirects, signals, waiting, GC
  integration. For managing long-lived processes, not one-shot commands.

## assert - error assertions for testament

[Testament](https://github.com/pyrmont/testament) matches an error message
**exactly**. A prose contract says a call "raises `ERR_BAD_KEY`"; the
implementation raises `ERR_BAD_KEY: duplicate`; testament's
`assert-thrown-message` fails on a correct implementation. This module
supplies the assertions testament does not have.

```janet
(import jennystats/assert :as a)
(import testament :as t)

(t/deftest "duplicate key is refused"
  (t/assert-expr (a/assert-raises-with "ERR_BAD_KEY" (fn [] (add k v)))))

(t/deftest "unknown key is accepted"
  (t/assert-expr (a/assert-not-raises (fn [] (add k v)))))
```

Five functions: `assert-raises-with`, `assert-raises`,
`assert-not-raises`, and the two predicates they build on, `raises` and
`error-message`. All return booleans and raise nothing, so they drop into
`assert-expr` or into any other harness.

Two behaviours to know:

- `assert-raises-with` matches a **prefix**, because a contract sentence
  names an error class and implementations append detail.
- Every helper takes a **function and invokes it**. Testament's
  `assert-thrown` takes a *form*, so `(t/assert-thrown (fn [] ...))`
  watches the closure being created rather than the call, and reports
  "No error thrown" whatever the code does.

Testament is optional: the module imports nothing but `./typed`, so a
project that has not adopted testament can still use the predicates.
The repo's own `test/smoke-assert-testament.janet` proves the integration
and is skipped by `run_tests.sh` when testament is not installed.

## Install

Clone anywhere, then either:

**Import by path** - zero setup, works everywhere. Include the `.janet`
extension: a path without one is read as a module name.

```janet
(import "/path/to/janet-kit/jennystats/typed.janet")
```

**Or make the modules importable by name** - if you keep a Janet module
directory, symlink the three files into it:

```bash
git clone https://github.com/jennystats/janet-kit janet-kit
mkdir -p /your/janet/module/dir/jennystats
ln -s "$(pwd)"/janet-kit/jennystats/{typed,kit,assert}.janet /your/janet/module/dir/jennystats
```

Then `(import jennystats/typed :prefix "")`,
`(import jennystats/kit :prefix "")` and
`(import jennystats/assert :as a)` work everywhere. All three modules
install together - kit's dependency on typed is module-relative and
resolves after install.

**Or with jpm** - installs into your module path:

```bash
jpm install https://github.com/jennystats/janet-kit
```

## Tests

```bash
./run_tests.sh
```

Runs the smokes from the repo root; tests use module-relative imports and
need no setup. The testament integration smoke runs only when testament is
installed, since it is an optional dependency.

## License

AGPLv3 - see `LICENSE`.

## AI assistance

The code in this repository was written with the assistance of a large
language model and reviewed by its maintainer.
