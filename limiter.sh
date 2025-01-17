#!/bin/bash
u_dir="/etc/adm-lite/userDIR"

function_dropb () {  
port_dropbear=`ps aux | grep dropbear | awk NR==1 | awk '{print $17;}'`
[[ $port_dropbear = "" ]] && return
log=/var/log/auth.log
loginsukses='Password auth succeeded'
echo ' '
pids=`ps ax |grep dropbear |grep  " $port_dropbear" |awk -F" " '{print $1}'`
for pid in $pids
do
    pidlogs=`grep $pid $log |grep "$loginsukses" |awk -F" " '{print $3}'`
    i=0
    for pidend in $pidlogs
    do
    let i=i+1
    done
    if [ $pidend ]; then
       login=`grep $pid $log |grep "$pidend" |grep "$loginsukses"`
       PID=$pid
       user=`echo $login |awk -F" " '{print $10}' | sed -r "s/'/ /g"`
       waktu=`echo $login |awk -F" " '{print $2"-"$1,$3}'`
       while [ ${#waktu} -lt 13 ]; do
       waktu=$waktu" "
       done
       while [ ${#user} -lt 16 ]; do
       user=$user" "
       done
       while [ ${#PID} -lt 8 ]; do
       PID=$PID" "
       done
     echo "$user $PID $waktu"
    fi
done
echo ""
return
}

function_onlines () {
(
unset _on
for user in `awk -F : '$3 > 900 { print $1 }' /etc/passwd |grep -v "nobody" |grep -vi polkitd |grep -vi system-`; do
usurnum=$(ps -u $user | grep sshd |wc -l)
[[ "$usurnum" -gt 0 ]] && _on+="$usurnum+"
usurnum=$(function_dropb | grep "$user" | wc -l)
[[ "$usurnum" -gt 0 ]] && _on+="$usurnum+"
done
#Terceira Etapa#
for userovpn in `cat /etc/passwd | grep ovpn | awk -F: '{print $1}'`; do
us=$(cat /etc/openvpn/openvpn-status.log | grep $userovpn | wc -l)
[[ "$us" != "0" ]] && _on+="1+"
done
#Usuarios Vencidos
datenow=$(date +%s)
for user in $(awk -F: '{print $1}' /etc/passwd); do
expdate=$(chage -l $user|awk -F: '/Account expires/{print $2}')
echo $expdate|grep -q never && continue
datanormal=$(date -d"$expdate" '+%d/%m/%Y')
expsec=$(date +%s --date="$expdate")
diff=$(echo $datenow - $expsec|bc -l)
echo $diff|grep -q ^\- && continue
vencidos[1]+="1+"
done
#Fazendo A Soma#
_on+="0"
_on=$(echo $_on|bc)
vencidos[1]+="0"
vencidos[1]=$(echo ${vencidos[1]}|bc)
echo "$_on" > ./onlines
echo "${vencidos[1]}" > ./vencidos
) &
}

fun_ovpn_onl () {
for userovpn in `cat /etc/passwd | grep ovpn | awk -F: '{print $1}'`; do
us=$(cat /etc/openvpn/openvpn-status.log | grep $userovpn | wc -l)
[[ "$us" != "0" ]] && echo "$userovpn"
done
}

function_usertime () {
(
declare -A data
declare -A time
declare -A time2
declare -A timefinal
tempousers="./tempo_conexao"
usr_pids_var="./userDIR"
[[ ! -e $tempousers ]] && touch $tempousers
_data_now=$(date +%s)
 for user in `awk -F : '$3 > 900 { print $1 }' /etc/passwd |grep -v "nobody" |grep -vi polkitd |grep -vi system-`; do
 unset ssh
 [[ -e $usr_pids_var/$user.pid ]] && source $usr_pids_var/$user.pid
ssh+="$(ps -u $user | grep sshd |wc -l)+"
ssh+="$(function_dropb | grep "$user" | wc -l)+"
[[ -e /etc/openvpn/server.conf ]] && ssh+="$(fun_ovpn_onl | grep "$user" | wc -l)+"
ssh+="0"
user_pid=$(echo $ssh|bc)
if [ "$user_pid" -gt "0" ]; then
 [[ "${data[$user]}" = "" ]] && data[$user]="$_data_now"
 if [ ! -e $usr_pids_var/$user.pid2  ]; then
  [[ -e $usr_pids_var/$user.pid ]] && cp $usr_pids_var/$user.pid $usr_pids_var/$user.pid2  
 fi
fi
if [ "$user_pid" = "0" ]; then
unset data[$user]
[[ -e "$usr_pids_var/$user.pid" ]] && rm $usr_pids_var/$user.pid
[[ -e $usr_pids_var/$user.pid2 ]] && rm $usr_pids_var/$user.pid2
fi
if [ "${data[$user]}" != "" ]; then
time[$user]=$(($_data_now - ${data[$user]}))
time2[$user]=$(cat $tempousers | grep "$user" | awk '{print $2}')
  [[ "${time2[$user]}" = "" ]] && time2[$user]="0"
timefinal[$user]=$((${time2[$user]} + ${time[$user]}))
_arquivo=$(cat $tempousers |grep -v "$user")
echo "$_arquivo" > $tempousers
echo "$user ${timefinal[$user]}" >> $tempousers
echo "data[$user]=$_data_now" > $usr_pids_var/$user.pid
fi
 done
) &
}

function_killmultiloguin () {
(
for user in `awk -F : '$3 > 900 { print $1 }' /etc/passwd |grep -v "nobody" |grep -vi polkitd |grep -vi system-`; do
unset pid_limite && unset sshd_on && unset drop_on
sshd_on=$(ps -u $user|grep sshd|wc -l)
drop_on=$(function_dropb|grep "$user"|wc -l)
[[ -e $u_dir/$user ]] && pid_limite=$(cat $u_dir/$user | grep "limite:" | awk '{print $2}') || pid_limite="999"
[[ $pid_limite != +([0-9]) ]] && pid_limite="999"
#LIMITE DROPBEAR
   [[ "$drop_on" -gt "$pid_limite" ]] && {
           kill=$((${drop_on}-${pid_limite}))
           pids=$(function_dropb|grep "$user"|awk '{print $2}'|tail -n${kill})
           for pid in `echo $pids`; do
           kill $pid
           done
    }
#LIMITE OPENSSH
   [[ "$sshd_on" -gt "$pid_limite" ]] && {
           kill=$((${sshd_on}-${pid_limite}))
           pids=$(ps x|grep [[:space:]]$user[[:space:]]|grep -v grep|grep -v pts|awk '{print $1}'|tail -n${kill})
           for pid in `echo $pids`; do
           kill $pid
           done
    }
done
sleep 3s
) &
}

fun_net () {
(
log_0="/tmp/tcpdum"
log_1="/tmp/tcpdump"
log_2="/tmp/tcpdumpLOG"
usr_dir="/etc/adm-lite/userDIR/usr_cnx"
[[ -e "$log_1" ]] &&  mv -f $log_1 $log_2
[[ ! -e $usr_dir ]] && touch $usr_dir
#ENCERRA TCP
for pd in `ps x | grep tcpdump | grep -v grep | awk '{print $1}'`; do
kill -9 $pd > /dev/null 2>&1
done
#INICIA TCP
tcpdump -s 50 -n 1> /tmp/tcpdump 2> /dev/null &
[[ ! -e /tmp/tcpdump ]] && touch /tmp/tcpdump
#ANALIZA USER
for user in `awk -F : '$3 > 900 { print $1 }' /etc/passwd | grep -v "nobody" |grep -vi polkitd |grep -vi system-`; do
touch /tmp/$user
ip_openssh $user > /dev/null 2>&1
ip_drop $user > /dev/null 2>&1
sed -i '/^$/d' /tmp/$user
pacotes=$(paste -sd+ /tmp/$user | bc)
rm /tmp/$user
if [ "$pacotes" != "" ]; then
  if [ "$(cat $usr_dir | grep "$user")" != "" ]; then
  pacotesuser=$(cat $usr_dir | grep "$user" | awk '{print $2}')
  [[ $pacotesuser = "" ]] && pacotesuser=0
  [[ $pacotesuser != +([0-9]) ]] && pacotesuser=0
  ussrvar=$(cat $usr_dir | grep -v "$user")
  echo "$ussrvar" > $usr_dir
  pacotes=$(($pacotes+$pacotesuser))
  echo -e "$user $pacotes" >> $usr_dir
  else
  echo -e "$user $pacotes" >> $usr_dir
  fi
fi
unset pacotes
done
) &
}

ip_openssh () {
user="$1"
for ip in `lsof -u $user -P -n | grep "ESTABLISHED" | awk -F "->" '{print $2}' |awk -F ":" '{print $1}' | grep -v "127.0.0.1"`; do
 packet=$(cat $log_2 | grep "$ip" | wc -l)
 echo "$packet" >> /tmp/$user
 unset packet
done
}

ip_drop () {
user="$1"
loguser='Password auth succeeded'
touch /tmp/drop
for ip in `cat /var/log/auth.log | tail -100 | grep "$user" | grep "$loguser" | awk -F "from" '{print $2}' | awk -F ":" '{print $1}'`; do
 if [ "$(cat /tmp/drop | grep "$ip")" = "" ]; then
 packet=$(cat $log_2 | grep "$ip" | wc -l)
 echo "$packet" >> /tmp/$user
 echo "$ip" >> /tmp/drop
 fi
done
rm /tmp/drop
}

while true; do
function_killmultiloguin > /dev/null 2>&1
sleep 7s
done