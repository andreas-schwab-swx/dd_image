#!/usr/bin/env bash
# ------------------------------------------------------------------------
#  Simple LVM Snapshot → XZ → SFTP-Backup
# ------------------------------------------------------------------------
#  • Liest seine Einstellungen aus /etc/dd_image/config.sh
#  • Legt einen COW-Snapshot an (Standard: 10 % der LV-Größe,
#    mindestens 1 GiB, höchstens freier VG-Platz)
#  • Erstellt ein komprimiertes Image (xz –3, Multi-Thread)
#  • Lädt es via SFTP hoch
#  • Entfernt Snapshot + temporäre Dateien (Trap-Cleanup)
# ------------------------------------------------------------------------

set -euo pipefail
shopt -s inherit_errexit  # damit auch in SFTP-Heredocs Fehler erkannt werden

# ------------------------------------------------------------------------
# 1) Konfiguration laden
# ------------------------------------------------------------------------
CONFIG_FILE="/etc/dd_image/config.sh"
if [[ ! -f $CONFIG_FILE ]]; then
  echo "Konfigurationsdatei nicht gefunden: $CONFIG_FILE" >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$CONFIG_FILE"

# ------------------------------------------------------------------------
# 2) Root-Prüfung
# ------------------------------------------------------------------------
if (( EUID != 0 )); then
  echo "Dieses Skript muss als root laufen." >&2
  exit 1
fi

# ------------------------------------------------------------------------
# 3) LV- und VG-Größen ermitteln
# ------------------------------------------------------------------------
read -r LV_SIZE_GiB VG_FREE_GiB <<<"$(lvs --noheadings --units g --nosuffix -o LV_SIZE "$LVM_VG/$LVM_LV" | tr -d ' ' \
                               && vgs --noheadings --units g --nosuffix -o VG_FREE "$LVM_VG" | tr -d ' ')"

# Snapshot-Größe: 10 % der LV-Größe, mindestens 1 GiB
SNAP_SIZE_GiB=$(( LV_SIZE_GiB * 10 / 100 ))
(( SNAP_SIZE_GiB < 1 )) && SNAP_SIZE_GiB=1
# nicht mehr als freie VG-Größe
if (( SNAP_SIZE_GiB > VG_FREE_GiB )); then
  echo "Nicht genügend freier Platz im VG ($VG_FREE_GiB GiB verfügbar, $SNAP_SIZE_GiB GiB benötigt)." >&2
  exit 1
fi

# Doppel-Bindestrich-Notation für /dev-Pfad vorbereiten
LVM_VG_PATH=${LVM_VG//-/--}
SNAPSHOT_PATH=${SNAPSHOT_NAME//-/--}
SNAP_DEV="/dev/$LVM_VG_PATH/$SNAPSHOT_PATH"

# ------------------------------------------------------------------------
# 4) Aufräumen bei Abbruch
# ------------------------------------------------------------------------
cleanup() {
  [[ -e $SNAP_DEV ]] && lvremove -f "$SNAP_DEV" >/dev/null 2>&1 || true
  [[ -n ${TEMP_FILE:-} && -f $TEMP_FILE ]] && rm -f "$TEMP_FILE"
}
trap cleanup EXIT

# ------------------------------------------------------------------------
# 5) Backup-Dateinamen ermitteln
# ------------------------------------------------------------------------
TODAY="$(date +%F)"
next_backup_index() {
  local idx=1
  while (( idx <= 99 )); do
    printf -v CANDIDATE "image-%s-%02d.img.xz" "$TODAY" "$idx"
    if ! sftp -q "$REMOTE_USER@$REMOTE_HOST" <<<"ls $REMOTE_PATH/$CANDIDATE" &>/dev/null; then
      echo "$CANDIDATE"
      return
    fi
    (( idx++ ))
  done
  return 1
}
BACKUP_FILE="$(next_backup_index)" || { echo "Tageslimit 99 Backups erreicht." >&2; exit 1; }

echo "### Simple LVM Backup Script ###"
echo "LV-Größe:          ${LV_SIZE_GiB} GiB"
echo "Snapshot-Größe:    ${SNAP_SIZE_GiB} GiB"
echo "Zielfile:          $BACKUP_FILE"

# ------------------------------------------------------------------------
# 6) Snapshot erstellen
# ------------------------------------------------------------------------
lvcreate -L "${SNAP_SIZE_GiB}G" -s -n "$SNAPSHOT_NAME" "$LVM_VG/$LVM_LV" >/dev/null
echo "Snapshot $SNAPSHOT_NAME erstellt."

# ------------------------------------------------------------------------
# 7) Snapshot sichern & komprimieren
# ------------------------------------------------------------------------
TEMP_FILE="$(mktemp --tmpdir=/dev/shm backup_XXXXXX.img.xz)"
export XZ_DEFAULTS="--memlimit=4GiB"
echo "Erstelle Backup (dd + xz)…"
dd if="$SNAP_DEV" bs=32M status=progress | xz -T0 -3 >"$TEMP_FILE"

# ------------------------------------------------------------------------
# 8) Upload via SFTP
# ------------------------------------------------------------------------
echo "Lade hoch nach $REMOTE_HOST:$REMOTE_PATH …"
sftp "$REMOTE_USER@$REMOTE_HOST" <<SFTP_CMDS
cd $REMOTE_PATH
put $TEMP_FILE $BACKUP_FILE
quit
SFTP_CMDS
echo "Upload erfolgreich."

# ------------------------------------------------------------------------
# 9) Fertig
# ------------------------------------------------------------------------
echo "Backup abgeschlossen: $BACKUP_FILE"
