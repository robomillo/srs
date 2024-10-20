#!/bin/sh

RELOAD_TABLES=false

while [ "$1" != "" ]; do
    case $1 in
        --tables )        RELOAD_TABLES=true
                          ;;
        * )               echo "Invalid option: $1"
                          exit 1
    esac
    shift
done

psql -h localhost -U srs -d srs -c "drop schema srs cascade"
psql -h localhost -U srs -d srs -c "set search_path = srs,public"
if [ "$RELOAD_TABLES" = true ]; then
    echo "Reloading tables..."
    psql -h localhost -U srs -d srs -f ./db/tables.sql
else
    psql -h localhost -U srs -d srs -c "create schema srs"
    echo "Skipping table reload..."
fi

psql -h localhost -U srs -d srs -f ./db/functions.sql
psql -h localhost -U srs -d srs -f ./db/api.sql

# psql -h localhost -U srs -d srs
