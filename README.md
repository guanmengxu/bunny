# 下载并解密 i.gpg，保存为 ./i.sh
bash <(curl -sSL https://raw.githubusercontent.com/guanmengxu/bunny/main/di.sh) i

# 下载并解密 foo.gpg，保存为 /root/foo.sh
bash <(curl -sSL https://raw.githubusercontent.com/guanmengxu/bunny/main/di.sh) foo /root/
bash <(curl -sSL https://raw.githubusercontent.com/guanmengxu/bunny/main/di.sh) foo /root/foo.sh
