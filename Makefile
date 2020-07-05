run: sel.sed test-prog.sel
	./sel.sed test-prog.sel

dbg.txt: sel.sed test-prog.sel
	timeout 0.5 sed --debug -E -f sel.sed test-prog.sel > dbg.txt

sel.sed: parser.sed runner.sed
	echo "#!/usr/bin/sed -nEf" > sel.sed
	cat parser.sed runner.sed >> sel.sed
	chmod a+x sel.sed

debug: dbg.txt
	nvim -O dbg.txt runner.sed

hs:
	runhaskell sel.hs

.PHONY: run debug hs
