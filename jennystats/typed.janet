# typed.janet - runtime type guards for Janet functions.
# (defn/typed name {:args [:kw...] :ret :kw} [args] "docstring?" body)
# A leading body string attaches as the defn docstring; the guards still
# wrap the remaining body.
# Public package: janet-kit. License: AGPLv3 (see LICENSE).
# Design notes: guard cost, error semantics, type keywords - see the README.
(def preds
  {:nil nil? :boolean boolean? :number number? :string string? :buffer buffer?
   :keyword keyword? :symbol symbol? :table table? :struct struct?
   :array array? :tuple tuple? :function function? :fiber fiber?
   :bytes (fn [x] (or (string? x) (buffer? x) (keyword? x) (symbol? x)))
   :any (fn [_] true)})

(put (curenv) :doc
     "Runtime type guards for Janet functions. defn/typed defines a
function whose arguments and return value are checked per call - see
preds for the type keywords. Part of the kit package.")

(defn- resolve-pred [kw]
  (or (get preds kw)
      (errorf "defn/typed: unknown type keyword %v (known: %s)"
              kw (string/join (map string (sort (keys preds))) " "))))

(defmacro defn/typed
  "Define a function with runtime type guards:
  (defn/typed name {:args [:kw...] :ret :kw} [params] \"docstring?\" body).
  A leading body string attaches as the docstring, hoisted above the
guards. Argument guards run before the body and their errors name
the argument index and expected type; the return guard wraps the
result. Fixed arity only - no varargs."
  [name spec args & body]
  (def arg-spec (get spec :args))
  (def ret-spec (get spec :ret))
  (unless arg-spec (errorf "defn/typed %s: spec is missing :args" (string name)))
  # (& rest) forms must fail here with attribution: when lengths happen to
  # match, the generated guards otherwise die as a cryptic "unknown symbol &"
  (when (find |(= $ '&) args)
    (errorf "defn/typed %s: varargs are not supported - fixed arity only"
            (string name)))
  (unless (= (length args) (length arg-spec))
    (errorf "defn/typed %s: %d args but spec has %d - compile-time arity error"
             (string name) (length args) (length arg-spec)))
  # a leading body string is the docstring - hoist it above the guards
  (def doc-str (when (string? (first body)) (first body)))
  (def body* (if doc-str (tuple/slice body 1) body))
  (def checks
    (seq [i :range [0 (length args)]]
      ~(unless (,(resolve-pred (arg-spec i)) ,(args i))
         (errorf "%s: arg %d expected %v, got %v"
                 ,(string name) ,i ,(arg-spec i) (type ,(args i))))))
  (def call ~(do ,;body*))
  (def ret-check
    (if ret-spec
      ~(let [r% ,call]
         (unless (,(resolve-pred ret-spec) r%)
           (errorf "%s: return expected %v, got %v" ,(string name) ,ret-spec (type r%)))
         r%)
      call))
  (if doc-str
    ~(defn ,name ,doc-str ,args ,;checks ,ret-check)
    ~(defn ,name ,args ,;checks ,ret-check)))
