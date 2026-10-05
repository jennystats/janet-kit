# typed.janet - runtime type guards for Janet functions.
# (defn/typed name {:args [:kw...] :ret :kw} [args] body)
# Public package: janet-kit. License: AGPLv3 (see LICENSE).
# Design notes: guard cost, error semantics, type keywords - see the README.
(def preds
  {:nil nil? :boolean boolean? :number number? :string string? :buffer buffer?
   :keyword keyword? :symbol symbol? :table table? :struct struct?
   :array array? :tuple tuple? :function function? :fiber fiber?
   :bytes (fn [x] (or (string? x) (buffer? x) (keyword? x) (symbol? x)))
   :any (fn [_] true)})

(defn- resolve-pred [kw]
  (or (get preds kw)
      (errorf "defn/typed: unknown type keyword %v (known: %s)"
              kw (string/join (map string (sort (keys preds))) " "))))

(defmacro defn/typed [name spec args & body]
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
  (def checks
    (seq [i :range [0 (length args)]]
      ~(unless (,(resolve-pred (arg-spec i)) ,(args i))
         (errorf "%s: arg %d expected %v, got %v"
                 ,(string name) ,i ,(arg-spec i) (type ,(args i))))))
  (def call ~(do ,;body))
  (def ret-check
    (if ret-spec
      ~(let [r% ,call]
         (unless (,(resolve-pred ret-spec) r%)
           (errorf "%s: return expected %v, got %v" ,(string name) ,ret-spec (type r%)))
         r%)
      call))
  ~(defn ,name ,args ,;checks ,ret-check))
