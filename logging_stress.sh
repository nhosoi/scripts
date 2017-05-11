PREFIX=${1:-"WORD_0"}
N=0
while [ $N -lt 1000 ]
do
logger -i -p local6.info -t stress_tag_${PREFIX} "short_message_${PREFIX}_$N"
N=`expr $N + 1`
done
