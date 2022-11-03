#!/bin/bash

LATEX_FOLDERS="./ FrontMatter BackMatter MainMatter ."
LATEX_EXTS=".aux .bcf .fdb_latexmk .fls .lof .log .lol .nlo .out .xml .gz .toc .bbl .blg" # .nav .snm .lot .bak .loa ~"

for FOLDER in $LATEX_FOLDERS
do
	for EXT in $LATEX_EXTS
	do
		rm $FOLDER/*$EXT
	done
done

# rm img/*-eps-converted-to.*

echo "Latex Cleaning DONE!!!"
