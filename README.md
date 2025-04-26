# 下载并解密 i.gpg，保存为 ./i.sh
bash <(curl -sSL https://raw.githubusercontent.com/guanmengxu/bunny/main/d.sh) i

# 下载并解密 foo.gpg，保存为 /root/foo.sh
bash <(curl -sSL https://raw.githubusercontent.com/guanmengxu/bunny/main/d.sh) i /root/

bash <(curl -sSL https://raw.githubusercontent.com/guanmengxu/bunny/main/d.sh) i /root/i.sh

#加密
gpg --symmetric --cipher-algo AES256 --output i.gpg i.sh
