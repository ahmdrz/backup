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

## How to use ?

0. git clone `https://github.com/ahmdrz/backup`.
1. run `sh mkbackup.sh <projectname>` in your terminal.
2. modify `<projectname>/<projectname>.sh` file and replace your configurations.
3. (optional) configure a `cronjob` for this backup script.