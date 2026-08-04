#!/usr/bin/env bash
# One command: build a throwaway database, apply every migration, prove that
# no company can see another's data. Non-zero exit means do not deploy.
set -euo pipefail
export PATH=/usr/lib/postgresql/16/bin:$PATH
MIGRATIONS="${1:?usage: run_isolation_test.sh <migrations-dir>}"
DB=isotest_$$
psql -h /tmp/pg -p 5433 -U postgres -q -c "create database $DB"
trap 'psql -h /tmp/pg -p 5433 -U postgres -q -c "drop database if exists $DB" >/dev/null 2>&1' EXIT
PSQL="psql -h /tmp/pg -p 5433 -U postgres -v ON_ERROR_STOP=1 -q -d $DB"
$PSQL -f /tmp/prelude.sql > /dev/null
for f in "$MIGRATIONS"/0*.sql; do
  $PSQL -f "$f" > /dev/null 2>&1 || { echo "migration failed: $(basename "$f")"; exit 1; }
done
psql -h /tmp/pg -p 5433 -U postgres -X -v ON_ERROR_STOP=1 -d "$DB" \
  -f "$(dirname "$0")/isolation_test.sql" 2>&1 \
  | sed -e 's/^psql:[^ ]*: //' -e 's/^NOTICE:  //' \
  | grep -E '^(pass|FAIL|ERROR)|ISOLATION'
exit "${PIPESTATUS[0]}"
