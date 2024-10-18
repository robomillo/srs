#!/bin/sh
# RELOAD SQL FUNCTIONS WITHOUT LOSING DATA

# Assumes you have already created database & tables:
# createuser srs
# createdb -O srs srs
# psql -U srs -d srs -f tables.sql

psql -h localhost -U srs -d srs -c "drop schema srs cascade"
psql -h localhost -U srs -d srs -c "set search_path = srs,public"
psql -h localhost -U srs -d srs -f ./db/tables.sql
psql -h localhost -U srs -d srs -f ./db/functions.sql
psql -h localhost -U srs -d srs -f ./db/api.sql

# psql -h localhost -U srs -d srs
