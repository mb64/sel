run: sel.sed test-prog.sel arith.sel
	./sel.sed test-prog.sel

dbg.txt: sel.sed test-prog.sel arith.sel
	timeout 0.5 sed --debug -E -f sel.sed test-prog.sel | sed -e 's/^COMMAND: */COMMAND: /' > dbg.txt

sel.sed: parser.sed runner.sed
	echo "#!/usr/bin/sed -nEf" > sel.sed
	cat parser.sed runner.sed >> sel.sed
	chmod a+x sel.sed

debug: dbg.txt
	nvim -O dbg.txt runner.sed

arith.sel: arith.py
	python arith.py > arith.sel

hs:
	runhaskell sel.hs

%.sec: %.sel *.sel parser.sed
	sed -Ef parser.sed $< > $@

.PHONY: run debug hs
