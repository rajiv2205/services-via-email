#! /bin/bash

#######################
# Date: 26 November, 2014
# Author: Rajiv Sharma
# License: GPL

# .subjectfile and .idfile are queue for Subjects and Message IDs of emails received by the server.
# .tmp file stores the Message ID of last executed service's email.
# Add the names of services in file "services.txt" (One service in one line without any space in the beginning). 
# If you want to exclude any service from the list then commane out the service name. 
# Add the emails addresses of authenticated users in file "validsenders.txt" to whom you want to give privildge for restarting services.

# .count file stores difference to setup queue of emails received by the server in 1 minute.

# Set a cron for this script under /etc/crontab in the following format:

#  */1 * * * * root bash -l -c 'sh services_email.sh'
#######################

countCheck=1
function initialization()
{
    location=`pwd`

    if [[ ! -f $location/.count ]];
        then
        sed -n '/To:/,/Content-Type/p' $MAIL | grep  "^Message-ID" | wc -l > $location/.count
    fi

    if [[ ! -f $location/.tmp ]]; 
        then
        touch $location/.tmp
    fi

    value_for_script          # Executing the function for script values 

}

function value_for_script()
{
    N=0
    count=`cat .count`
    newcount=`sed -n '/To:/,/Content-Type/p' $MAIL | grep  "^Message-ID" | wc -l`
    lastid=`cat .tmp | cut -d ',' -f1`

    if [ "$newcount" != "$count" ];
        then
        number=`expr $newcount - $count`
        sed -n '/To:/,/Content-Type/p' $MAIL | grep  "^Subject" | tail -$number | sed 's/^Subject: \(.*\)/\1/' > .subjectfile
        sed -n '/To:/,/Content-Type/p' $MAIL | grep  "^Message-ID" | tail -$number | sed 's/^Message-ID: \(.*\)/\1/' | sed 's/^<\(.*\)/\1/' | sed 's/.$// ' > .idfile
        sed -n '/To:/,/Content-Type/p' $MAIL | grep  "^From" | tail -$number |sed 's/^From: \(.*\)/\1/' > .temp_sender.txt
cat .temp_sender.txt | while read w;
do
acceptEmail             # Executes the function for every sender in the list and checks the format of email address.
countCheck=1
done 
  
    else
        echo "up-to-date"
    fi
}

function acceptEmail() {
  
    if [[ "$countCheck" > 2 ]]; then
        echo "exit" 
        exit 1
    else

        if [[ ! "$w" =~ ^[-0-9a-zA-Z.+_]+@[-0-9a-zA-Z.+_]+\.[a-zA-Z]{2,4} ]];
            then
                countCheck=$((countCheck+1))
                w=`echo "$w" | sed 's/.*<\(.*\)/\1/' | sed 's/.$// '`
                acceptEmail
            else
                                 
		echo "$w" > .senderfile
		subjectFetcher    # Calling function to fetch subject, messageid and email sender address from the queues.

        fi
    fi
}

function subjectFetcher()
{

            N=$((N+1))
            SUBJECT=`sed -n ''$N'p' .subjectfile`                    
            messageid=`sed -n ''$N'p' .idfile`
            fromaddr=`sed -n ''1'p' .senderfile`
            #echo "$fromaddr"
            valid_users_check        # Calling function for valid users present in the file "validsender.txt"
}

function valid_users_check()
{
        for k in $(cat validsender.txt | grep -v "^#")
        do
                if [[ "$k" == "$fromaddr" ]];
                    then
                        messageid_check             # Executing function to check message ID's (any recent email)
                fi
        done
}

function messageid_check()
{
        if [ "$messageid" != "$lastid" ];
                then
           
     service_Executer     # Executing the main service execution function.
        fi
}

function acknowledge_Sender()
{
  if [ $status -eq 0 ];
                then
                    echo -e "Hi Admin, \n \nI have $acknowl daemon at `date` \n \nroot" | mail -s "IMPORTANT: Server Message" $(cat validsender.txt | grep -v "^#")
                    echo $messageid > .tmp
                    echo $newcount > .count
                else
                echo "There is some problem,  not $acknowl at `date`" >> logfile
  fi
}

function service_Executer()
{
        for i in $(cat services.txt | grep -v "^#")
do
        if [[ "$i restart" == "$SUBJECT" ]];
        then
                /etc/init.d/$SUBJECT 2>> logfile
                status=$?
                acknowl="restarted $i"
                acknowledge_Sender
        
        elif [[ "$i reload" == "$SUBJECT" ]];
        then
                /etc/init.d/$SUBJECT 2>> logfile
                status=$?
                acknowl="reloaded $i"
                acknowledge_Sender

        elif [[ "$i start" == "$SUBJECT" ]];
        then
                /etc/init.d/$SUBJECT 2>> logfile
                status=$?
                acknowl="started $i"
                acknowledge_Sender

        elif [[ "$i stop" == "$SUBJECT" ]];
        then
                /etc/init.d/$SUBJECT 2>> logfile
                status=$?
                acknowl="stopped $i"
                acknowledge_Sender
        fi
done
}

initialization  # Main Execution 

