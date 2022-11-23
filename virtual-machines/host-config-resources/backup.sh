#!/bin/bash

export USER="max"
export REMOTE_SFTP_HOST="176.9.44.19"

deps(){
 sudo apt-get install restic
}

sftp(){
  restic -r sftp:$USER@$REMOTE_SFTP_HOST:/srv/restic-repo init
}

manual(){

    export RSYNC_SKIP_COMPRESS='3fr/3g2/3gp/3gpp/7z/aac/ace/amr/apk/appx/appxbundle/arc/arj/arw/asf/avi/bz2/cab/cr2/crypt[5678]/dat/dcr/deb/dmg/drc/ear/erf/flac/flv/gif/gpg/gz/iiq/iso/jar/jp2/jpeg/jpg/k25/kdc/lz/lzma/lzo/m4[apv]/mef/mkv/mos/mov/mp[34]/mpeg/mp[gv]/msi/nef/oga/ogg/ogv/opus/orf/pef/png/qt/rar/rpm/rw2/rzip/s7z/sfx/sr2/srf/svgz/tbz/tgz/tlz/txz/vob/wim/wma/wmv/xz/zip'

    export USER="max"
    export HOST="192.168.50.50"
    export PORT="22"
    export REMOTE_DIR="/"
    export LOCAL_DIR="/home/$USER/repos/Scrap-Metal/virtual-machines"
    export FILE="debiancloud.tgz"
    export LOG_FILE="/var/log/transfers.log"
    export SSH_KEY_FILE="/home/max/.ssh/max"
    export CYPHER="aes128-gcm@openssh.com"

    touch $LOG_FILE

    rsync --times \
    --archive \
    --log-file="$LOG_FILE" \
    --inplace \
    --checksum \
    --compress \
    --skip-compress="$RSYNC_SKIP_COMPRESS" \
    --recursive \
    --human-readable \
    --verbose \
    --progress \
    -p -b -e "ssh -o Compression=no -x" $LOCAL_DIR/$FILE $USER@$HOST:$REMOTE_DIR

}

deps
sftp
