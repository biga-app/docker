#!/bin/sh
# Dumps the database to backups/biga-<time>.dump (pg_dump custom format). With
# compose.s3.yaml running it also archives the object store next to it, as
# backups/biga-<time>.objects.tar. Restore with ./scripts/restore.sh <file>.
set -eu
cd "$(dirname "$0")/.."
mkdir -p backups
umask 077
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
file="backups/biga-$stamp.dump"
docker compose exec -T postgres pg_dump -U biga -d biga --format=custom >"$file"
echo "Wrote $file ($(wc -c <"$file" | tr -d ' ') bytes)"

# Content is immutable and only ever added to between sweeps, so an archive
# taken after the dump holds everything the dump refers to.
if [ -n "$(docker compose ps --status running -q s3 2>/dev/null)" ]; then
	objects="backups/biga-$stamp.objects.tar"
	docker compose exec -T s3 tar -C /data -cf - . >"$objects"
	echo "Wrote $objects ($(wc -c <"$objects" | tr -d ' ') bytes)"
fi
