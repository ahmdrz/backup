#!/bin/bash

config_file="config.json"

if [ $# -gt 0 ]; then
    config_file=$1
fi

command=""

if ! [ -x "$(command -v pg_dump)" ]; then
  command="$command postgresql postgresql-contrib"
fi

if ! [ -x "$(command -v sshpass)" ]; then
  command="$command sshpass"
fi

if ! [ -x "$(command -v curl)" ]; then
  command="$command curl"
fi

if ! [ -x "$(command -v zip)" ]; then
  command="$command zip"
fi

if ! [ -x "$(command -v jq)" ]; then
  command="$command jq"
fi

if ! [ -z "$command" ]; then
    # only for debian base linux distributions.
    echo "~ installing $command"
    sudo apt install $command
fi

if ! [ -f "$config_file" ]; then
    echo 'Error: There is no config file'
    exit 1
fi

get_config() {
    cat $config_file | jq -r $1
}

PROJECT_NAME=$(get_config '.project_name')
echo "~ creating $PROJECT_NAME"
mkdir -p $PROJECT_NAME
backup_path="$PROJECT_NAME/backup_$(date +%s%3N)"
LOG_FILE="$backup_path/backup.log"
mkdir $backup_path
alias date_now='date +"[%Y-%m-%d %H:%M:%S]"'
alias unix_time='date +%s%3N'

echo "$(date_now) backup initilized by $(whoami)" > $LOG_FILE

# Configurations
PG_ENABLE=$(get_config '.postgres.enable')
PG_DBNAME=$(get_config '.postgres.name')
PG_USERNAME=$(get_config '.postgres.username')
PG_PASSWORD=$(get_config '.postgres.password')
PG_PORT=$(get_config '.postgres.port')
PG_HOST=$(get_config '.postgres.host')

SMTP_MAIL_ENABLE=$(get_config '.smtp.enable')
SMTP_MAIL_TARGET=$(get_config '.smtp.target')
SMTP_MAIL_FROM=$(get_config '.smtp.from')
SMTP_MAIL_PASSWORD=$(get_config '.smtp.password')
SMTP_MAIL_HOST=$(get_config '.smtp.host')
SMTP_MAIL_PORT=$(get_config '.smtp.port')

SCP_ENABLE=$(get_config '.scp.enable')
SCP_HOST=$(get_config '.scp.host')
SCP_PORT=$(get_config '.scp.port')
SCP_USERNAME=$(get_config '.scp.username')
SCP_TEMP=$(get_config '.scp.directories')
SCP_DIRECTORIES=""
SCP_PASSWORD=$(get_config '.scp.password')

index=0
while true; do
    temp_input=$(get_config ".scp.directories[$index]")    
    if [ $temp_input = null ]; then
        break
    fi
    SCP_DIRECTORIES="$SCP_DIRECTORIES $temp_input"
    index=$((index+=1))
done

# Something like : Tell me on telegram
FINISHER_ENABLE=$(get_config '.finisher.enable')
FINISHER_CMD=$(get_config '.finisher.command')

echo "$(date_now) backup script started" >> $LOG_FILE

if [ $PG_ENABLE = "true" ]
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

if [ $SCP_ENABLE = "true" ]
then	
    echo "~ scp: starting"
	echo "$(date_now) SCP backup archive from $SCP_HOST to localhost" >> $LOG_FILE    
    for scp_dir in $SCP_DIRECTORIES
	do
		sshpass -p $SCP_PASSWORD scp -q -P $SCP_PORT -rp $SCP_USERNAME@$SCP_HOST:$scp_dir $backup_path
        if [ $? -eq 0 ];then
            echo "$(date_now) SCP for $scp_dir has been finished" >> $LOG_FILE
        else
            echo "$(date_now) SCP , an error occurred ($scp_dir)" >> $LOG_FILE
        fi
	done
    echo "~ scp: end"
fi

if [ $SMTP_MAIL_ENABLE = "true" ]
then
    echo "~ email: starting"
    echo "$(date_now) email sender started" >> $LOG_FILE
	# status=$(curl -s -w %{http_code} --output /dev/null --url 'smtps://'$SMTP_MAIL_HOST':'$SMTP_MAIL_PORT' --ssl-reqd --mail-from $SMTP_MAIL_FROM --mail-rcpt $SMTP_MAIL_TARGET --upload-file $LOG_FILE --user $SMTP_MAIL_FROM':'$SMTP_MAIL_PASSWORD --insecure --fail)
    if [ $? -eq 0 ];then
        echo "$(date_now) email has been sent to $SMTP_MAIL_TARGET" >> $LOG_FILE
    else
        echo "$(date_now) email not sent to $SMTP_MAIL_TARGET , an error occurred , status code : $status" >> $LOG_FILE
    fi
    echo "~ email: finished"
fi

if [ $FINISHER_ENABLE = "true" ]
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