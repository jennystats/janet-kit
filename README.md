# janet-kit

Two small modules for Janet utility scripting. Each helper exists because
the underlying Janet API has a behaviour that is easy to get wrong - the
helper is the workaround, written down so it does not have to be
rediscovered.

Part of [Jenny Stats](https://github.com/jennystats), a home for Janet
data and statistics packages. Jenny is just Janet.

| module            | what                                                | API                          |
|-------------------|-----------------------------------------------------|------------------------------|
| `typed.janet`     | runtime type guards for functions                   | `defn/typed` macro           |
| `kit.janet`       | shell / path / file helpers that encode the gotchas | 11 functions                 |

Core stdlib only. No native modules, no build step, no C toolchain.
Developed and tested on Janet 1.42.

## typed - typed function definitions

```janet
(import typed :prefix "")

(defn/typed half {:args [:number] :ret :number} [x] (/ x 2))

(half 4)   # -> 2
(half "x") # error: half: arg 0 expected :number, got string
```

- Type spec: `{:args [:string :number] :ret :string}`.
- Known types: `:nil :boolean :number :string :buffer :keyword :symbol
  :table :struct :array :tuple :function :fiber :bytes :any`.
- Arity mismatch between arglist and spec, unknown type keywords and a
  missing `:args` key are **compile-time** errors; `:ret` is optional
  (omit it, or pass nil, for no return check). Value guards run at call
  time.
- Guard predicates resolve at macro expansion, so a guard costs one direct
  predicate call - about 310ns per call for 3 guards on Janet 1.42.

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
  output is captured via temp file. Returns trimmed stdout.
- `sh-quote s` / `sh-join parts` - rebuilding a shell command by
  space-joining argv re-splits paths containing spaces; re-quote. `$` and
  backticks still expand inside the quotes - do not pass hostile strings.
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

## Install

Clone anywhere, then either:

**Import by path** - zero setup, works everywhere:

```janet
(import "/path/to/janet-kit/typed")
```

**Or make the modules importable by name** - if you keep a Janet module
directory, symlink the two files into it:

```bash
git clone https://github.com/jennystats/janet-kit janet-kit
ln -s "$(pwd)/janet-kit/typed.janet" "$(pwd)/janet-kit/kit.janet" /your/janet/module/dir
```

Then `(import typed :prefix "")` and
`(import kit :prefix "")` work everywhere. Both modules install together -
kit's dependency on typed is module-relative and resolves after install.

**Or with jpm** - installs into your module path:

```bash
jpm install https://github.com/jennystats/janet-kit
```

## Tests

Run from the repo root; tests use module-relative imports and need no
setup.

```bash
janet test/smoke-typed.janet
janet test/smoke-kit.janet x y
```

## License

GPLv3 - see `LICENSE`.

## AI assistance

The code in this repository was written with the assistance of a large
language model and reviewed by its maintainer.
