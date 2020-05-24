#!/bin/bash

# pdfman opens a man page as a PDF
function pdfman() {
 man -t "${1}" | open -f -a /Applications/Preview.app/
}

# waitforinput blocks the process until any 1 character input is received
function waitforinput() {
  read -sr -n 1
}

# now prints the current time in the format YEAR-MON-DAY HOUR:MIN:SEC
function now() {
  date +"%Y-%m-%d %H:%M:%S"
}

# timestamp prints the current Epoch time
function timestamp() {
  date +%s
}

# `recentmods n m` returns all files in n path that were modified within m days
# e.g. to find all documents modified within 10 days:
# recentmods ~/Documents 10
function recentmods() {
  find "$1" -type f -mtime -"$2" -exec ls -l {} \;
}
