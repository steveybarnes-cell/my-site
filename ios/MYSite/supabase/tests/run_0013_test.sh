#!/bin/bash
# Runs every migration on a throwaway local Postgres, then the 0013 checks.
#   PGHOST=/path/to/socket PGPORT=5432 PGUSER=postgres ./run.sh
# Needs a Postgres you can create databases on. Never point it at Supabase.
set -e
cd "$(dirname "$0")"
M=../migrations
P="psql -q -v ON_ERROR_STOP=1"
$P -c "drop database if exists mysite_test" -c "create database mysite_test" >/dev/null
$P -d mysite_test -f supabase-shim.sql >/dev/null
for f in $M/00*.sql; do
  [ "$(basename $f)" = "0013_join_requests.sql" ] && $P -d mysite_test -f 0013_seed.sql >/dev/null
  $P -d mysite_test -f "$f" >/dev/null 2>/tmp/mysite-mig.err || { echo "FAILED $(basename $f)"; grep -v NOTICE /tmp/mysite-mig.err | head; exit 1; }
done
psql -q -At -d mysite_test -f 0013_join_requests_test.sql 2>&1 | grep -E "^  (ok|FAIL)|passed|ERROR"
