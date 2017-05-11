PREFIX=${1:-"WORD"}
CNT=0
while [ $CNT -lt 1000 ]
do
sh logging_stress.sh ${PREFIX}_$CNT &
CNT=`expr $CNT + 1`
done
