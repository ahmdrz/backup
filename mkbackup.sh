#!/bin/bash

PROJECT_NAME="$1"

mkdir -p $PROJECT_NAME

echo "#!/bin/bash" > $PROJECT_NAME/$PROJECT_NAME.sh
echo 'backup_path="backup_$(date +%s%3N)"' >> $PROJECT_NAME/$PROJECT_NAME.sh

cat backup.sh >> $PROJECT_NAME/$PROJECT_NAME.sh

echo "$PROJECT_NAME created."