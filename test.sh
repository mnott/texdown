#!/bin/bash
#
# Set log4p level to any of
#
# OFF, FATAL, ERROR, WARN, INFO, DEBUG, TRACE, ALL
#
# Using export:
#
# export LOGLEVEL=DEBUG
#
# or just saying
#
# LOGLEVEL=DEBUG ./test.sh
#
# (The latter option wins even if you did use export)
#

inline2test t/inline2test.ini

LOGLEVEL=$LOGLEVEL prove -l $@;
