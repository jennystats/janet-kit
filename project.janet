# project.janet - jpm package manifest for janet-kit.
(declare-project
  :name "janet-kit"
  :description "Runtime type guards and shell/path/file helpers for Janet utility scripting"
  :license "GPL-3.0"
  :version "0.1.0")

(declare-source
  :source ["typed.janet" "kit.janet"])
