# backup
My personal backup script

1. Backup from PostgreSQL databases
2. Backup from File or Directory using scp
3. Notify on email using SMTP
4. Backup to one file with Zip method.

## Dependencies

1. sshpass
2. zip
3. curl
4. pg_dump
5. jq

## How to use ?

0. git clone `https://github.com/ahmdrz/backup`.
1. modify `config.json` file.
2. run `sh backup.sh`.
3. (optional) configure a `cronjob` for this backup script.

**NOTE**

You can use `sh backup.sh <config_file>` for change configuration file name.
Default is `config.json`

This project is forked from [narbehaj/backup](https://gitlab.com/narbehaj/backup)
