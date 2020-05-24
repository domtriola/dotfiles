#!/bin/bash

# pdfman opens a man page as a PDF
function pdfman() {
 man -t "${1}" | open -f -a /Applications/Preview.app/
}

# now prints the current time in the format YEAR-MON-DAY HOUR:MIN:SEC
function now() {
  date +"%Y-%m-%d %H:%M:%S"
}

# timestamp prints the current Epoch time
function timestamp() {
  date +%s
}
