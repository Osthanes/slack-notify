#!/bin/bash

#********************************************************************************
# Copyright 2014 IBM
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#********************************************************************************

#############
# Colors    #
#############
export green='\e[0;32m'
export red='\e[0;31m'
export label_color='\e[0;33m'
export no_color='\e[0m' # No Color

if [ -z "$*" ]; then
    echo -e " usage:  `basename $0` message\n\n  SLACK_WEBHOOK_PATH environment variable must be set, format: T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX\n  SLACK_COLOR environment variable can be set to color the message\n    Valid values are good, warning, danger or a hex value like #439FE0"
    exit 1
fi

if [ -z "$SLACK_WEBHOOK_PATH" ]; then
    echo -e "${red}SLACK_WEBHOOK_PATH environment variable must be set before invoking this script${no_color}"
fi

if [ -z "$SLACK_COLOR" ]; then
    echo -e "You can set the color using the SLACK_COLOR environment variable\n   Valid values are good, warning, danger or a hex value like #439FE0"
    SLACK_COLOR="d3d3d3"
fi

echo $SLACK_WEBHOOK_PATH | grep "https://hooks.slack.com/services/"
FULL_PATH=$?
if [ $FULL_PATH -ne 0 ]; then 
    URL="https://hooks.slack.com/services/$SLACK_WEBHOOK_PATH"
else 
    URL=$SLACK_WEBHOOK_PATH
fi 
MSG=$(echo "$*" | sed 's/"/\\\"/g')

# If we are running in an IDS job set a URL for the sender 
if [ -n "${IDS_PROJECT_NAME}" ]; then 
    echo "setting sender"
    MY_IDS_PROJECT=${IDS_PROJECT_NAME##*| } 
    MY_IDS_USER=${IDS_PROJECT_NAME%% |*}
    MY_IDS_URL="${IDS_URL}/${MY_IDS_USER}/${MY_IDS_PROJECT}"
    SENDER="<${MY_IDS_URL}|${MY_IDS_PROJECT}-${MY_IDS_USER}>"
    MSG="${SENDER}: ${MSG}"
    echo ${MSG}
else
    echo "not setting sender:${IDS_PROJECT_NAME}"
fi 

echo $PAYLOAD
PAYLOAD="{\"attachments\":[{""\"text\": \"$MSG\", \"color\": \"$SLACK_COLOR\"}]}"

curl -X POST --data-urlencode "payload=$PAYLOAD" $URL
