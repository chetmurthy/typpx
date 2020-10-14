
EXE=test.byte

test: all
	for e in $(EXE); do echo -n $$e ": " ; ./$$e; done

all: $(EXE)

.SUFFIXES: .ml .byte

.ml.byte:
	ocamlfind ocamlc -package ppx_type_of $< -o $@

clean::
	rm -f *.cm* *.byte
