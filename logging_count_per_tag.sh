ID=${1:-0}
PREFIX=${2:-"WORD"}
EPOD=`oc get pods -l component=es-ops -o=name 2> /dev/null | sed -e "s/pod.*\///"`
if [ "$EPOD" = "" ]; then
    EPOD=`oc get pods -l component=es -o=name 2> /dev/null | sed -e "s/pod.*\///"`
fi
if [ "$EPOD" = "" ]; then
    echo "Error: Failed to get the ES pod"
    exit 1
fi 
SECRETPATH="/etc/elasticsearch/secret"
prevmessage=""
prevtimestamp=""
timestamp=""
while [ $ID -lt 1000 ]
do
    TAG="stress_tag_${PREFIX}_$ID"
    echo "Tag: $TAG"
    count=`oc exec $EPOD -- curl -s -k --cert $SECRETPATH/admin-cert --key $SECRETPATH/admin-key "https://localhost:9200/.operations.**/_search?size=9999&q=systemd.u.SYSLOG_IDENTIFIER:$TAG" | python -mjson.tool | egrep "\<$TAG\>" | wc -l`
    echo $count
    if [[ $VERBOSE ]]; then
        for val in `oc exec $EPOD -- curl -s -k --cert $SECRETPATH/admin-cert --key $SECRETPATH/admin-key "https://localhost:9200/.operations.**/_search?sort="@timestamp"&size=9999&q=systemd.u.SYSLOG_IDENTIFIER:$TAG" | python -mjson.tool | egrep "\"@timestamp\":|\"message\":" | awk '{print $2}'`
        do
            if [ `expr "$val" : ".*message"` -gt 0 ]; then
                echo "$timestamp : $val"
                if [ `expr "$timestamp" \< "$prevtimestamp"` -gt 0 -a \
                     `expr "$val" \< "$prevmessage"` -gt 0 ]; then
                    echo WARNING: $val was stored after $prevmessage
exit 1
                fi
                prevmessage="$val"
            elif [ `expr "$val" : ".20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]"` -gt 0 ]; then
                prevtimestamp="$timestamp"
                timestamp="$val"
            fi
        done
    fi
    echo "=============="
    echo "Check journald"
    echo "=============="
    jcount=`journalctl | egrep "\<$TAG\>" | wc -l`
    if [ $jcount -eq $count ]; then
       echo "  Counts matched: $jcount"
    else
       echo "  Counts not matched: ES=$count vs. journalctl=$jcount"
    fi
    echo "=============="
    echo "Check messages"
    echo "=============="
    mcount=`sudo egrep "\<$TAG\>" /var/log/messages | wc -l`
    if [ $mcount -eq $count ]; then
       echo "  Counts matched: $mcount"
    else
       echo "  Counts not matched: ES=$count vs. messages=$mcount"
    fi
    if [ "$1" != "" ]; then
        exit 0
    fi
    ID=`expr $ID + 1`
    echo ""
done
