#!/usr/bin/env bash
# Usage: ./set_registry_auth.sh <username> [htpasswd file, default auth/htpasswd]
# Adds the user or changes their password; the password is read from stdin.
set -euo pipefail

user=${1:?usage: $0 <username> [htpasswd file]}
file=${2:-auth/htpasswd}
IFS= read -rsp "Password for $user: " password
echo

umask 077
mkdir -p "$(dirname "$file")"
touch "$file"

# Registry accepts only bcrypt (-B); the password goes via stdin (-i) to stay out of `ps`
hash=$(printf '%s\n' "$password" | docker run --rm -i httpd:2.4.69 htpasswd -niB "$user")

# Literal match on the name field: a regex would let "a.b" also drop "axb"
{ awk -F: -v u="$user" '$1 != u' "$file"; echo "$hash"; } > "$file.new"
mv "$file.new" "$file"
echo "Saved $user to $file. Restart the registry to apply: docker compose restart registry"
