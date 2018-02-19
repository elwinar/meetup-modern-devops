.PHONY: help
help:: ## print this message
	@grep -E '^[a-zA-Z_-]+::.*?## .*$$' $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST)) | sort | awk 'BEGIN {FS = "::.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: serve
serve:: ## start the Remarker server on port 6275
	./node_modules/.bin/remarker serve

.PHONY: build
build:: ## build the slides deck in HTML and PDF
	./node_modules/.bin/remarker build
	wkhtmltopdf --page-width 111 --page-height 148 -B 0 -L 0 -R 0 -T 0 -O "Landscape" build/index.html build/index.pdf
