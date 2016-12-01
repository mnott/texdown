#!/bin/bash

inline2test t/inline2test.cfg

if [[ $# > 0 ]]; then
	prove -l $@;
else
	prove -l
fi