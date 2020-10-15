
all:
	dune build @install

install::
	dune install

uninstall::
	dune uninstall

clean::
	dune clean
	for i in $(TESTDIRS); do make -C examples/$$i/tests clean ; done

TESTDIRS=ppx_curried_constr ppx_overload ppx_type_of

test::  clean all uninstall install
	for i in $(TESTDIRS); do make -C examples/$$i/tests clean test ; done

OCAMLVERS=09
OCAMLSRC=/home/chet/Hack/Ocaml/GENERIC/4.$(OCAMLVERS).0/.opam-switch/sources/ocaml-base-compiler.4.$(OCAMLVERS).0

diffs::
	(cd examples/ppx_curried_constr && ./MAKE-DIFF $(OCAMLSRC))
