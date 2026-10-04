(import ../typed :prefix "")

# clean call
(defn/typed half {:args [:number] :ret :number} [x] (/ x 2))
(assert (= (half 4) 2) "clean call")

# runtime arg guard: message carries function name, expected and actual
(var guard-fired false)
(try (half "x") ([e] (set guard-fired (not (nil? (string/find "expected :number" e))))))
(assert guard-fired "arg guard fired with message")

# the guard reports the FAILING argument's index, not always arg 0
(defn/typed two {:args [:number :string] :ret :number} [a b] a)
(var idx-msg nil)
(try (two 1 2) ([e] (set idx-msg e)))
(assert (not (nil? (string/find "arg 1 expected :string" idx-msg)))
        "arg guard reports the failing index")

# runtime return guard
(defn/typed bad-ret {:args [:number] :ret :string} [x] x)
(var ret-msg nil)
(try (bad-ret 1) ([e] (set ret-msg e)))
(assert (not (nil? (string/find "return expected :string" ret-msg)))
        "return guard fired with message")

# :bytes accepts the whole bytes family; :any accepts everything
(defn/typed bytes-fn {:args [:bytes] :ret :any} [x] x)
(assert (= (bytes-fn "s") "s") ":bytes accepts strings")
(assert (= (bytes-fn :kw) :kw) ":bytes accepts keywords")
(assert (deep= (bytes-fn @"buf") @"buf") ":bytes accepts buffers")
(defn/typed any-fn {:args [:any] :ret :any} [x] x)
(assert (deep= (any-fn [1]) [1]) ":any accepts anything")

# zero-argument functions
(defn/typed zero-fn {:args [] :ret :number} [] 7)
(assert (= (zero-fn) 7) "empty :args spec defines a zero-arg function")

# compile-time: arity mismatch between arglist and spec
(var arity-error false)
(try (eval ~(defn/typed bad {:args [:number :number]} [a] a))
  ([e] (set arity-error (not (nil? (string/find "compile-time arity error" e))))))
(assert arity-error "compile-time arity error")

# compile-time: unknown type keyword in :args and in :ret
(var bad-args-kw nil)
(try (eval ~(defn/typed bad2 {:args [:nope] :ret :any} [a] a))
  ([e] (set bad-args-kw e)))
(assert (not (nil? (string/find "unknown type keyword :nope" bad-args-kw)))
        "unknown :args keyword is a compile-time error")
(var bad-ret-kw nil)
(try (eval ~(defn/typed bad3 {:args [:number] :ret :nope} [x] x))
  ([e] (set bad-ret-kw e)))
(assert (not (nil? (string/find "unknown type keyword :nope" bad-ret-kw)))
        "unknown :ret keyword is a compile-time error")

# regression: a missing :args spec key used to surface as a raw janet
# macro error ("(macro) expected string, symbol, keyword, ... got nil")
(var missing-args nil)
(try (eval ~(defn/typed bad4 {:ret :any} [a] a))
  ([e] (set missing-args e)))
(assert (not (nil? (string/find "missing :args" missing-args)))
        "missing :args spec key errors with a clear compile-time message")
(set missing-args nil)
(try (eval ~(defn/typed bad5 {} [a] a))
  ([e] (set missing-args e)))
(assert (not (nil? (string/find "missing :args" missing-args)))
        "empty spec errors on :args too")

# compile-time: varargs are rejected with a clear message (a matched-length
# (& rest) form used to surface as a cryptic "unknown symbol &")
(var varargs-err nil)
(try (eval ~(defn/typed vrest {:args [:number :number] :ret :any} [& rest] 42))
  ([e] (set varargs-err e)))
(assert (not (nil? (string/find "varargs" varargs-err)))
        "(& rest) forms are rejected at compile time")
(set varargs-err nil)
(try (eval ~(defn/typed vrest2 {:args [:number :number :number] :ret :any}
              [a & rest] a))
  ([e] (set varargs-err e)))
(assert (not (nil? (string/find "varargs" varargs-err)))
        "[a & rest] forms are rejected at compile time")

# :ret is optional by design: omitted (or nil) means no return check
(var no-ret-err nil)
(try (eval ~(defn/typed no-ret {:args [:number]} [x] (string "v" x)))
  ([e] (set no-ret-err e)))
(assert (nil? no-ret-err) "omitted :ret is allowed")
(assert (= (no-ret 1) "v1") "omitted :ret means no return guard")

(print "typed smoke ok")
