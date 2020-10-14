
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

