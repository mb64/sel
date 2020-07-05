run:
	echo | ./sel.sed

dbg.txt: sel.sed
	echo | timeout 0.2 sed --debug -E -f sel.sed > dbg.txt

sel.sed: parser.sed runner.sed
	echo "#!/usr/bin/sed -nEf" > sel.sed
	cat parser.sed runner.sed >> sel.sed
	chmod a+x sel.sed

debug: dbg.txt
	nvim -O dbg.txt sel.sed

hs:
	runhaskell sel.hs

.PHONY: run debug hs
