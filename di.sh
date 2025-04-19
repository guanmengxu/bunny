#!/bin/bash

url="https://github.com/guanmengxu/bunny/releases/latest/download/i.gpg"

#outfile="./i.sh"
outfile="/root/i.sh"

tmpfile="$(mktemp -t i_gpg_XXXXXX.gpg)"

echo "[*] Downloading encrypted script..."
curl -sSL "$url" -o "$tmpfile" || {
  echo "[!] Failed to download"
  rm -f "$tmpfile"
  exit 1
}

echo "[*] Decrypting script (enter password when prompted)..."
if gpg -o "$outfile" -d "$tmpfile"; then
  chmod +x "$outfile"
  echo "[+] Decryption successful: $outfile"
  echo "[>] Run it manually: bash $outfile"
else
  echo "[!] Decryption failed"
  rm -f "$tmpfile"
  exit 1
fi

rm -f "$tmpfile"
rm -f "$0"
