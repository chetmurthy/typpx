#!/bin/bash
# Test only works when ppx_type_of is installed

rm -f /tmp/testXX*
ocamlfind not-ocamlfind/papr_official.exe -binary-output -impl test.ml /tmp/testXX.1
ocamlfind ppx_type_of/ppx.exe -debug -typpx-dump-first /tmp/testXX.1 /tmp/testXX.2
ocamlfind not-ocamlfind/papr_official.exe -binary-input -impl /tmp/testXX.2

exit

not-ocamlfind preprocess -verbose  -package ppx_type_of test.ml

ocamlfind ocamlc -verbose -package ppx_type_of -o test_ test.ml
./test_
