# 1) 只解密到 ./i.sh
bash <(curl -sSL https://raw.githubusercontent.com/guanmengxu/bunny/main/d.sh) i

# 2) 解密到 /root/i.sh
bash <(curl -sSL https://raw.githubusercontent.com/guanmengxu/bunny/main/d.sh) /root/i

# 3) 解密并执行 ./i.sh
bash <(curl -sSL https://raw.githubusercontent.com/guanmengxu/bunny/main/d.sh) i -e

# 4) 解密并执行 ./i.sh，同时传 -e --foo
bash <(curl -sSL https://raw.githubusercontent.com/guanmengxu/bunny/main/d.sh) i -e -e --foo

# 加密
gpg --symmetric --cipher-algo AES256 --output i.gpg i.sh
