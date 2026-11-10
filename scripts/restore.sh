#!/bin/sh
# Restores a dump from ./scripts/backup.sh, replacing the current data. If an
# objects archive sits next to it and compose.s3.yaml is in use, the object
# store is restored too.
set -eu
cd "$(dirname "$0")/.."
if [ $# -ne 1 ] || [ ! -f "$1" ]; then
	echo "usage: restore.sh backups/biga-<time>.dump" >&2
	exit 2
fi
printf 'This replaces every session in the database with %s. Continue? [y/N] ' "$1"
read -r answer
case "$answer" in y | Y | yes) ;; *) echo "Cancelled."; exit 1 ;; esac
objects="${1%.dump}.objects.tar"
use_objects=""
if [ -f "$objects" ] && docker compose config --services | grep -qx s3; then
	use_objects=1
fi
docker compose stop server
docker compose exec -T postgres pg_restore -U biga -d biga --clean --if-exists --no-owner <"$1"
if [ -n "$use_objects" ]; then
	docker compose stop s3
	docker compose run --rm --no-deps -T --entrypoint sh s3 -c 'rm -rf /data/* /data/.[!.]* 2>/dev/null; tar -C /data -xf -' <"$objects"
	docker compose start s3
fi
docker compose start server
echo "Restored $1."
