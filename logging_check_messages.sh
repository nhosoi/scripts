PREFIX=${1:-"WORD"}
VERSION=${2:-`oc version | egrep openshift | awk '{print $2}' | awk -F'-' '{print $1}'`}
FPOD=`oc get pods -l component=fluentd -o=name 2> /dev/null | sed -e "s/pod.*\///"`
EPOD=`oc get pods -l component=es-ops -o=name 2> /dev/null | sed -e "s/pod.*\///"`

MESSAGES="/var/log/messages"

if [ "$EPOD" = "" ]; then
    EPOD=`oc get pods -l component=es -o=name 2> /dev/null | sed -e "s/pod.*\///"`
    if [ "$EPOD" = "" ]; then
        echo "Error: There is no elasticsearch pod"
        exit 1
    fi
fi

if [ "$FPOD" = "" ]; then
    echo "Error: There is no fluentd pod"
    exit 1
fi

if [ "$VERSION" = "" ]; then
    echo "Failed to retrieve VERSION.  Using \"unknown\""
    VERSION=unknown
fi

SECPATH="/etc/elasticsearch/secret"
OUT="/tmp/${VERSION}.out"
TMP="/tmp/${VERSION}.tmp"
prevlog=""
echo "Version $VERSION, Fluentd $FPOD, ES $EPOD" > $OUT
echo "==================================================================================" >> $OUT
while true
do
    lastline=""
    while [ "$lastline" = "" ]
    do
        if [ -f $MESSAGES ]; then
            lastline=`sudo egrep "stress_tag_${PREFIX}.* short_message_${PREFIX}" $MESSAGES | tail -n 1`
        else
            lastline=`journalctl | egrep "stress_tag_${PREFIX}.* short_message_${PREFIX}" | tail -n 1`
        fi
        sleep 1
    done

    IFS=' ' read -a elems <<< "$lastline"
    lastlog="${elems[5]}"
    if [ "$prevlog" = "$lastlog" ]; then
        echo "Done - lastlog: $lastline" | tee $TMP; cat $TMP >> $OUT
        exit 0
    fi
    lastepoch=`date --date="${elems[1]}-${elems[0]}-2017 ${elems[2]}" +%s`
    prevlog=$lastlog
    
    echo "Search $lastlog" | tee $TMP; cat $TMP >> $OUT
    
    found=false
    retry=0
    while [ "$found" = "false" ]
    do
        oc exec $EPOD -- curl -s -k --cert ${SECPATH}/admin-cert --key ${SECPATH}/admin-key "https://localhost:9200/.operations.**/_search?q=message:${lastlog}" | python -mjson.tool | egrep "${lastlog}" 2>&1 | tee $TMP
    
        if [ -s $TMP ]; then
            cat $TMP >> $OUT
            stored=`date +%s`
            echo Delta between logged time ${lastepoch} and stored time ${stored}: `expr $stored - $lastepoch` | tee $TMP; cat $TMP >> $OUT; echo "" >> $OUT
            found=true
        else
            retry=`expr $retry + 1`
            mod=`expr $retry % 100`
            if [ $mod -eq 0 ]; then
                echo Retried $retry times. | tee $TMP; cat $TMP >> $OUT
            fi
        fi
    done

    echo "Check log speed" | tee $TMP; cat $TMP >> $OUT
    sh check-log-speed.sh 2>&1 | tee $TMP; cat $TMP >> $OUT

    oc get pods 2>&1 | tee $TMP; cat $TMP >> $OUT
    oc logs $FPOD 2>&1 | tee $TMP; cat $TMP >> $OUT
    echo "==================================================================================" >> $OUT
done
