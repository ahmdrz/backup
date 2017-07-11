#!/bin/bash

if ! [ -x "$(command -v sshpass)" ]; then
  echo 'Error: sshpass not found. Let me install it...' >&2
  sudo apt install sshpass  
fi

if ! [ -x "$(command -v curl)" ]; then
  echo 'Error: curl not found. Let me install it...' >&2
  sudo apt install curl  
fi

if ! [ -x "$(command -v zip)" ]; then
  echo 'Error: zip not found. Let me install it...' >&2
  sudo apt install zip  
fi

alias date_now='date +"[%Y-%m-%d %H:%M:%S]"'
alias unix_time='date +%s%3N'

backup_path="backup_$(unix_time)"

LOG_FILE="$backup_path/backup.log"
mkdir $backup_path

echo "$(date_now) backup initilized by $(whoami)" > $LOG_FILE


# Configurations
PG_ENABLE="no"
PG_DBNAME=""
PG_USERNAME=""
PG_PASSWORD=""
PG_PORT="5432"
PG_HOST=""

SMTP_MAIL_ENABLE="no"
SMTP_MAIL_TARGET=""
SMTP_MAIL_FROM=""
SMTP_MAIL_PASSWORD=""
SMTP_MAIL_HOST="smtp.gmail.com"
SMTP_MAIL_PORT="465"

SCP_ENABLE="no"
SCP_HOST=""
SCP_PORT="22"
SCP_USERNAME=""
SCP_PATH=""
SCP_PASSWORD=""

# Something like : Tell me on telegram
FINISHER_ENABLE="yes"
FINISHER_CMD="echo bye $(whoami)"


echo "$(date_now) backup script started" >> $LOG_FILE

if [ $PG_ENABLE = "yes" ]
then
    echo "~ postgres: starting"
    if [ $(whoami) = "root" ]
    then
        cp /root/.pgpass /root/.pgpass_$current_unix_time.bak > /dev/null 2> /dev/null
		echo "$PG_HOST:$PG_PORT:$PG_DBNAME:$PG_USERNAME:$PG_PASSWORD" > /root/.pgpass
		chmod 600 /root/.pgpass
    else
        cp /home/$(whoami)/.pgpass /home/$(whoami)/.pgpass_$current_unix_time.bak > /dev/null 2> /dev/null
		echo "$PG_HOST:$PG_PORT:$PG_DBNAME:$PG_USERNAME:$PG_PASSWORD" > /home/$(whoami)/.pgpass
		chmod 600 /home/$(whoami)/.pgpass
    fi

    current_unix_time=$(unix_time)
    echo "$(date_now) postgres backup started" >> $LOG_FILE
    ionice -c 3 pg_dump -p $PG_PORT -h $PG_HOST -Fc -U $PG_USERNAME $PG_DBNAME > $backup_path/postgres.dump | tee -a $LOG_FILE
    if [ $? -eq 0 ];then
        echo "$(date_now) postgres dumped to postgres.dump" >> $LOG_FILE
    else
        echo "$(date_now) cannot dump postgres" >> $LOG_FILE
    fi
    echo "~ postgres: end"
fi

if [ $SCP_ENABLE = "yes" ]
then	
    echo "~ scp: starting"
	echo "$(date_now) SCP backup archive from $SCP_HOST to localhost" >> $LOG_FILE
    mkdir -p $backup_path/scp/
    sshpass -p $SCP_PASSWORD scp -P $SCP_PORT -r $SCP_USERNAME@$SCP_HOST:$SCP_PATH $backup_path/scp/
    if [ $? -eq 0 ];then
        echo "$(date_now) SCP OK" >> $LOG_FILE
    else
        echo "$(date_now) SCP , an error occurred" >> $LOG_FILE
    fi
    echo "~ scp: end"
fi

if [ $SMTP_MAIL_ENABLE = "yes" ]
then
    echo "~ email: starting"
    echo "$(date_now) email sender started" >> $LOG_FILE
	status=$(curl -s -w %{http_code} --output /dev/null --url 'smtps://'$SMTP_MAIL_HOST':'$SMTP_MAIL_PORT --ssl-reqd --mail-from $SMTP_MAIL_FROM --mail-rcpt $SMTP_MAIL_TARGET --upload-file $LOG_FILE --user $SMTP_MAIL_FROM':'$SMTP_MAIL_PASSWORD --insecure --fail)
    if [ $? -eq 0 ];then
        echo "$(date_now) email has been sent to $SMTP_MAIL_TARGET" >> $LOG_FILE
    else
        echo "$(date_now) email not sent to $SMTP_MAIL_TARGET , an error occurred , status code : $status" >> $LOG_FILE
    fi
    echo "~ email: finished"
fi

if [ $FINISHER_ENABLE = "yes" ]
then
    echo "~ finisher: starting"
    echo "$(date_now) running finisher command" >> $LOG_FILE 
    $FINISHER_CMD
    echo "~ finisher: end"
fi

echo "~ zipping..."
echo "$(date_now) backup finished" >> $LOG_FILE
zip -r "$backup_path.zip" $backup_path -q
if [ $? -eq 0 ]
then    
    rm -rf $backup_path
else
    echo "~ Cannot create zip file from $backup_path"
fi