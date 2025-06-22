x.abs:  lsp_pour_ricco59.s lsp_dsp.s
	rmac -fb -s -u lsp_pour_ricco59.s
	rln   -o $@ -w -rq -a 4000 x x lsp_pour_ricco59.o -em -z
