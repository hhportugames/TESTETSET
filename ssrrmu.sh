#!/bin/bash
echo ""
wget -q -O /tmp/ssr https://raw.githubusercontent.com/hhportugames/TESTETSET/main/bar/msg2
cat /tmp/ssr > /tmp/ssrrmu.sh
wget -q -O /tmp/ssr https://www.dropbox.com/s/w7oyb3da169kxsg/C-SSR.sh
cat /tmp/ssr >> /tmp/ssrrmu.sh
#curl  https://www.dropbox.com/s/re3lbbkxro23h4g/C-SSR.sh >> 
sed -i "s;VPS•MX;ChumoGH-ADM;g" /tmp/ssrrmu.sh
sed -i "s;@Kalix1;ChumoGH;g" /tmp/ssrrmu.sh
sed -i "s;VPS-MX;chumogh;g" /tmp/ssrrmu.sh
chmod +x /tmp/ssrrmu.sh && bash /tmp/ssrrmu.sh
#sed '/gnula.sh/ d' /tmp/ssrrmu.sh > /bin/ejecutar/crontab