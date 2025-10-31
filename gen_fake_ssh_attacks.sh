#!/usr/bin/env bash
set -euo pipefail

# number of entries to generate
COUNT=${1:-1000}

# some example usernames to mix
USERS=(root admin test guest ubnt pi sshuser vb11x invaliduser)

# ranges to pick "source IPs" from (you can edit)
RANGES=( "45.77" "185.199" "203.0" "198.51" "192.0" "8.8" "13.58" "3.7" )

for i in $(seq 1 $COUNT); do
  # pick random prefix and three octets
  PREFIX=${RANGES[RANDOM % ${#RANGES[@]}]}
  IP="$PREFIX.$((RANDOM % 254 + 1)).$((RANDOM % 254 + 1))"
  USER=${USERS[RANDOM % ${#USERS[@]}]}
  PORT=$((1024 + RANDOM % 60000))
  # choose message template
  if (( RANDOM % 5 == 0 )); then
    MSG="Failed password for $USER from $IP port $PORT ssh2"
  else
    MSG="Failed password for invalid user $USER from $IP port $PORT ssh2"
  fi
  # optional: also log "Accepted password" occasionally to add noise (commented out)
  if (( RANDOM % 100 == 0 )); then
     logger -p authpriv.info -t sshd "Accepted password for $USER from $IP port $PORT ssh2"
  fi
  logger -p authpriv.warning -t sshd "$MSG"
  # small sleep to vary timestamps; tune as needed
  sleep 0.01
done
