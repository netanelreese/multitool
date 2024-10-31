#!/bin/bash

#############################################################################
# Utility Script to prep checksums and parchive files of data burnt to discs.
#############################################################################

# Ensure the script is run with root permissions
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Set the directories for checksums and PAR2 files
SOURCE="$(pwd)/source/"
CHECKSUM_DEST="./dest/checksum/"
PAR2_DEST="./dest/parchive"

# Create directories if they don't exist
mkdir -p "${CHECKSUM_DEST}" || { echo "Failed to create checksum directory"; exit 1; }
mkdir -p "${PAR2_DEST}" || { echo "Failed to create PAR2 directory"; exit 1; }

# Generate SHA256 checksums and PAR2 files for each file in the current directory and subdirectories
find "${SOURCE}" -type f -not -path "${CHECKSUM_DEST}/*" -not -path "${PAR2_DEST}/*" | while read -r file; do
    # Generate checksum and store in CHECKSUM_DEST
    checksum_file="${CHECKSUM_DEST}/$(basename "${file}").sha256"
    sha256sum "${file}" > "${checksum_file}" || echo "Checksum failed for ${file}"

    # Generate PAR2 file with 10% redundancy and store in PAR2_DEST
    pushd ${PAR2_DEST}
    par2 create -r32 -v "${file}" || echo "PAR2 creation failed for ${file}"
    popd
done

find "${SOURCE}" -name "*.par2" -print0 | while IFS= read -r -d '' file; do
    mv "$file" "${PAR2_DEST}"
done

echo "Backup script complete. Checksums saved to ${CHECKSUM_DEST}, PAR2 files saved to ${PAR2_DEST}."
