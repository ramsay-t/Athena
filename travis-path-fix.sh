#!/bin/bash
sed -i 's| env: \[z3cmd: "[^"]*"\]| env: \[z3cmd: "'`pwd`'/Z3-str_20140720/Z3-str.py"\]|' mix.exs 
