#!/bin/sh
# run_tests.sh - janet-kit smoke suite (typed + kit); runs from the repo root.
if janet test/smoke-typed.janet && janet test/smoke-kit.janet x y; then
  echo "RESULT: pass"
else
  echo "RESULT: fail"
  exit 1
fi
