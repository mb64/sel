run:
	echo | ./sel.sed

dbg.txt: sel.sed
	echo | timeout 0.2 sed --debug -E -f sel.sed > dbg.txt

debug: dbg.txt
	nvim -O dbg.txt sel.sed

.PHONY: run debug
