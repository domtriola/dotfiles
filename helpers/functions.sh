#!/bin/bash

# Open man page as PDF
function pdfman() {
 man -t "${1}" | open -f -a /Applications/Preview.app/
}
