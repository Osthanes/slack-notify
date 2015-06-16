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

# Return codes for various errors
RC_BAD_USAGE=254
RC_NOTIFY_MSG_USAGE=2
RC_NOTIFY_LEVEL_USAGE=3
RC_SLACK_WEBHOOK_PATH=4

# Slack color types
SLACK_COLOR_GOOD="good"
SLACK_COLOR_WARNING="warning"
SLACK_COLOR_DANGER="danger"

#############################################################################
# usage
#############################################################################

usage()
{
   /bin/cat << EOF
Send notification massage.
Usage: [-m notify_message]
       [-l notify_level] [-m notify_message]
       [-h]

Options:
  -m    Use notification massage for user input
  -l    Use notification level for user input. You can set the notification level using the NOTIFY_LEVEL environment variable.
        Valid values are 'good', 'info', or 'bad'. 
  -h    Display this help message and exit

Notes:
  SLACK_WEBHOOK_PATH: Specify the Slack Webhook URL
    In order to send Slack notification you must specify the Slack Webhook URL
    in an environment variable called 'SLACK_WEBHOOK_PATH' like this:
      SLACK_WEBHOOK_PATH=T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
    You can use or create a new Slack Webhook URL using the following steps:
      1. Go to Slack Integration page of your project (https://blue-alchemy.slack.com/services).
      2. Find the Incoming WebHooks and Click on 'Configured'.
      3. You can add new Webhook URL or select existing one.
  SLACK_COLOR: Specify the color of the border along the left side of the message. 
    It is an optional environment variable.
    The value can either be one of 'good', 'warning', 'danger', or any hex color code (eg. #439FE0).
    If you set this optional environment, then, you don't need to set '-l notify_level' option when you call this script.
     
EOF
}

#############################################################################
# echo messages
#############################################################################
msgid_2()
{
    echo -e "${red}Notification massage must be used when invoking this script.${no_color}"
}

msgid_3()
{
    echo -e "${red}Notification massage must be used with the -l notify_level option when invoking this script.${no_color}."
}

msgid_4()
{
    echo -e "${red}SLACK_WEBHOOK_PATH environment variable must be set before invoking this script${no_color}"
    echo -e "In order to send Slack notification you must specify the Slack Webhook URL"
    echo -e "in an environment variable called 'SLACK_WEBHOOK_PATH' like this:"
    echo -e "export SLACK_WEBHOOK_PATH=T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
    echo -e "You can use or create a new Slack Webhook URL using the following steps:"
    echo -e "   1. Go to Slack Integration page of your project (https://blue-alchemy.slack.com/services) "
    echo -e "   2. Find the Incoming WebHooks and Click on 'Configured'"
    echo -e "   3. You can add new Webhook URL or select existing one."}
}

#############################################################################
# die Functions
#############################################################################
die()
{
   msgid_${1}
   exit ${1}
}

#############################################################################
# Main
#############################################################################

# Set options from the command line.
while getopts ":m:l:h:" FLAG; do
   case ${FLAG} in
      m) NOTIFY_MSG=${OPTARG} ;;
      l) NOTIFY_LEVEL=${OPTARG} ;;
      h) usage && exit 0;;
      ?) usage && exit ${RC_BAD_USAGE}
   esac
done

shift $((OPTIND-1))
INVALID_ARGUMENTS=$*
[ -n "${INVALID_ARGUMENTS}" ] && usage && exit ${RC_BAD_USAGE}
[ -z "${NOTIFY_MSG}" ] && usage && die ${RC_NOTIFY_MSG_USAGE}
[ -z "${NOTIFY_LEVEL}" ] && [ -z "${NOTIFY_MSG}" ] && usage && die ${RC_NOTIFY_LEVEL_USAGE}

# Check if the SLACK_COLOR set in environment variable, then use SLACK_COLOR for the setting the color.
# If SLACK_COLOR is not set, then check the NOTIFY_LEVEL and set it to the SLACK_COLOR.
# If both SLACK_COLOR and NOTIFY_LEVEL are not set, then don't specify the color by setting SLACK_COLOR to null. 
if [ -z "$SLACK_COLOR" ]; then 
    if [ -n "$NOTIFY_MSG" ] && [ -n "NOTIFY_LEVEL" ]; then
        NOTIFY_LEVEL=$(echo $NOTIFY_LEVEL | tr '[:upper:]' '[:lower:]')
        case $NOTIFY_LEVEL in
            GOOD|good)
                SLACK_COLOR=$SLACK_COLOR_GOOD;;
            BAD|bad)
                SLACK_COLOR=$SLACK_COLOR_DANGER;;
            INFO|info)
                SLACK_COLOR=$SLACK_COLOR_WARNING;;
            *) 
                SLACK_COLOR="";;
        esac
    fi
else
    SLACK_COLOR=$(echo $SLACK_COLOR | tr '[:upper:]' '[:lower:]')
fi 

# Check if the message token has been set
if [ -z "$SLACK_WEBHOOK_PATH" ]; then
    die ${RC_SLACK_WEBHOOK_PATH}
fi

# Send message to the Slack
if [ -n "$SLACK_WEBHOOK_PATH" ]; then
    echo $SLACK_WEBHOOK_PATH | grep "https://hooks.slack.com/services/"
    FULL_PATH=$?
    if [ $FULL_PATH -ne 0 ]; then 
        URL="https://hooks.slack.com/services/$SLACK_WEBHOOK_PATH"
    else 
        URL=$SLACK_WEBHOOK_PATH
    fi 

    MSG="${NOTIFY_MSG}"

    # If we are running in an IDS job set a URL for the sender 
    if [ -n "${IDS_PROJECT_NAME}" ]; then 
        echo -e "setting sender"
        MY_IDS_PROJECT=${IDS_PROJECT_NAME##*| } 
        MY_IDS_USER=${IDS_PROJECT_NAME%% |*}
        MY_IDS_URL="${IDS_URL}/${MY_IDS_USER}/${MY_IDS_PROJECT}"
        SENDER="<${MY_IDS_URL}|${MY_IDS_PROJECT}-${MY_IDS_USER}>"
        MSG="${SENDER}: ${NOTIFY_MSG}"
    else
        echo "not setting sender:${IDS_PROJECT_NAME}"
    fi 

    echo -e "Slack message: ${MSG}"

    PAYLOAD="{\"attachments\":[{""\"text\": \"$MSG\", \"color\": \"$SLACK_COLOR\"}]}"
    echo -e "Slack Payload: ${PAYLOAD}"

    curl -X POST --data-urlencode "payload=$PAYLOAD" $URL
fi
