# Stress test scripts for logging

## Preparation

Disable RateLimit in /etc/systemd/journald.conf as follows not to lose logs 
due to the log burst as well as the trimming.
   See journald.conf(5) for details.

    In the Journal section:

    RateLimitInterval=0
    RateLimitBurst=0
    SystemMaxUse=4G
    RuntimeMaxUse=4G
    MaxFileSec=1month

   Restart journald
   \# systemctl restart systemd-journald.service

Disable RateLimit in /etc/rsyslog.conf as follows.
   See rsyslog.conf(5) for details.

    In the GLOBAL DIRECTIVES section:

    $SystemLogRateLimitInterval 0
    $SystemLogRateLimitBurst 0

    $IMJournalStateFile imjournal.state
    $imjournalRatelimitInterval 0
    $imjournalRatelimitBurst 0

   Restart rsyslog
   \# systemctl restart rsyslog.service

## Run

In one window:

    $ logging_stress_all.sh [WORD] 

    Description - launches 1000 logging_stress.sh in the background manner.
        WORD is used for tag: stress_tag_WORD_tagid [tagid: 0 - 999] and
            message: short_message_WORD_tagid_messageid [messageid: 0 - 999]

In another window:

    $ logging_check_messages.sh [WORD [VERSION]]

    Description - Picking up the last test logging message from messages or journald,
        searching the message in the elasticsearch, then comparing the stored time in
        messages/journald with the time found in the elasticsearch.
        WORD is the same string given to logging_stress_all.sh
        VERSION is used for the Version output and the output file
                by default, v#.#.# part returned from "oc version".

    Sample output 
    Version v3.6.0, Fluentd logging-fluentd-zgr5b, ES logging-es-ops-cqoee63r-1-d783t
    ==================================================================================
    Search short_message_WORD_990_999
                    "message": "short_message_WORD_990_999",
    Delta between logged time 1494391677 and stored time 1494447286: 55609

    Check log speed
    last record read by Fluentd: May 10 16:14:47 host-192-168-78-2.openstacklocal ...
    last record in the journal: May 10 16:14:48 host-192-168-78-2.openstacklocal ...
    Fluentd is 1.64729 seconds behind the journal
    Fluentd is 5 records behind the journal
    last record from a project container: May 10 16:14:43 host-192-168-78-2.openstacklocal ...
    Elasticsearch operations index is 1.931615 seconds behind the journal
    Traceback (most recent call last):
      File "<string>", line 1, in <module>
    IndexError: list index out of range
    Elasticsearch has no index or data for projects
    Elasticsearch operations index is 0.866886 seconds behind Fluentd

    NAME                              READY     STATUS      RESTARTS   AGE
    logging-es-1cfpamh9-1-9wrr3       1/1       Running     0          22h
    logging-es-ops-cqoee63r-1-d783t   1/1       Running     0          22h
    logging-fluentd-zgr5b             1/1       Running     0          21h
    ....
    ==============================================================================
    Done - lastlog: May 10 00:47:57 host-192-168-78-2 stress_tag_WORD_990[829]: short_message_WORD_990_999

Once all the log messages are stored in the elasticsearch:

    $ logging_count_per_tag.sh [ID [WORD]]

    Description - Search messages with logging tag "stress_tag_WORD_ID" on the elasticsearch
	    and count the messages belonging to the tag, where WORD is the same string given to
		logging_stress_all.sh
		Then, count the messages in journald and /var/log/messages and compare the 3 counts.

		If an environment variable VERBOSE is set, messages are dupmed with the timestamp.

