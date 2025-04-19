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

# Ask for password (no echo)
read -s -p "[*] Enter passphrase: " pass
echo

# Decrypt using the passphrase
if echo "$pass" | gpg --batch --yes --no-tty --pinentry-mode loopback \
  --passphrase-fd 0 -o "$outfile" -d "$tmpfile"; then
  chmod +x "$outfile"
  echo "[+] Decryption successful: $outfile"
  echo "[>] Run it manually: bash $outfile"
else
  echo "[!] Decryption failed"
  rm -f "$tmpfile"
  exit 1
fi

# Cleanup
rm -f "$tmpfile"
rm -f "$0"
#gpgconf --reload gpg-agent
#gpgconf --kill gpg-agent
