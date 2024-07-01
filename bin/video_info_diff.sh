#!/bin/bash

mediainfo "$1" > "${HOME}"/mediainfo_diff_1.txt
mediainfo "$2" > "${HOME}"/mediainfo_diff_2.txt

meld "${HOME}"/mediainfo_diff_1.txt "${HOME}"/mediainfo_diff_2.txt

