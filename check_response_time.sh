#!/bin/bash

# (c) 2008-2010, Roman Ovchinnikov aka CoolCold
# coolthecold@gmail.com


PROGNAME=$(basename $0)

#setting defaults
DEFAULT_INTERVAL=1
DEFAULT_ITERATIONS=$(( 60 * 60 * 2)) # 2 hours
DEFAULT_COMPRESSION=NO
DEFAULT_COOKIE=NO
DEFAULT_DUMP=NO
DATE_CMD="date +%s"


print_usage() {
  echo "Usage: $PROGNAME -u <url> [-C <cookie file>] [-c] [-i <interval>] [-I <iterations] [-D] [-S]"
  echo ""
  echo "-u <url> - something like http://fe.banners.mail.ru/js/show.js or http://assets0.github.com/stylesheets/bundle_common.css?2f7e714f544c24700e52868163f325fbc5239a18"
  echo "-C <cookie file> - file which contains cookies server may require, in curl format"
  echo "-c - enable compression support, so server may return gzipped content, for example"
  echo "-i <interval> - interval to do requests, in seconds"
  echo "-I <iterations> - how much requests should be taken"
  echo "-D - enable dump of headers for each request to stderr"
  echo "-S - show command being executed on stderr (command should be exact, but if in doubt, use bash -x /path/to/script)"
  echo "---"
  echo "Hint: use smth like 'cat show_flash.nginx_banners.txt|cut -f 2 -d \" \" |cut -f 2 -d \":\"|sort -n|uniq -c' to view largest times sets"
}

print_help() {
  echo "$PROGNAME"
  echo ""
  print_usage
  echo ""
  echo "This script tryes to connect to url and writeout connection/total times operation took."
  echo "It may be useful while testing how fast your webserver reponses on queries"
}

if [[ $# -eq "0"  ]]; then
  #no arguments were specified...very, very bad
  print_help
  exit 0
fi

#applying defaults
INTERVAL=$DEFAULT_INTERVAL
ITERATIONS=$DEFAULT_ITERATIONS
USE_COMPRESSION=$DEFAULT_COMPRESSION
COOKIE_FILE=$DEFAULT_COOKIE
URL=""
DUMP_HEADERS=$DEFAULT_DUMP
SHOW_COMMAND=NO

# Parse Arguments

while getopts ":hcDSu:i:I:C:" Option; do
  case $Option in
    h)
      print_help
      exit 0
      ;;
    u)
      URL=${OPTARG}
      ;;
    c)
      USE_COMPRESSION=YES
      ;;
    i)
      INTERVAL=${OPTARG}
      ;;
    I)
      ITERATIONS=${OPTARG}
      ;;
    C)
      COOKIE_FILE="${OPTARG}"
      ;;
    D)
      DUMP_HEADERS="YES"
      ;;
    S)
      SHOW_COMMAND="YES"
      ;;
    *)
      print_help
      exit 0
      ;;
  esac
done
shift $(($OPTIND - 1))

#validating && translating

if [[ "x$URL" == "x" ]]; then
  echo "URL must be specified!"
  print_usage
  exit 1
fi

if [[ "$USE_COMPRESSION" == "YES" ]]; then
  COMPRESS_ARG="--compressed"
else
  COMPRESS_ARG=""
fi

COOKIE_ARG=""
if [[ "x$COOKIE_FILE" != "xNO" && "x$COOKIE_FILE" != "x" ]]; then
  COOKIE_ARG="-b \"$COOKIE_FILE\""
  #COOKIE_PARAMS="$COOKIE_FILE"
fi

DUMP_ARG=""
if [[ "x$DUMP_HEADERS" == "xYES" ]]; then
  DUMP_ARG="-D -"
fi


#requesting url in cycle
for i in $(seq 1 $ITERATIONS); do
  curdate=$($DATE_CMD)
  CURL_ARGS="-o /dev/null $COOKIE_ARG $COMPRESS_ARG $DUMP_ARG -w '%{time_total} %{time_connect}\n' $URL"
  if [[ "x$SHOW_COMMAND" == "xYES" ]]; then
    echo "command is: curl $CURL_ARGS 2>/dev/null" 1>&2
  fi

  #CURL_DATA=$(eval curl "-o /dev/null $COOKIE_ARG $COMPRESS_ARG $DUMP_ARG -w '%{time_total} %{time_connect}\n' $URL" 2>/dev/null)
  CURL_DATA=$(eval curl "$CURL_ARGS" 2>/dev/null)
  EXT_CODE=$?
  if [[ $EXT_CODE -ne 0 ]]; then
    if [[ $EXT_CODE -eq 127 ]]; then #command not found
      echo "is curl installed? try \"sudo apt-get install curl\" to fix this";exit 1
    fi
  fi

  if [[ "x$CURL_DATA" = "x" ]]; then
    #empty curl data, way strange
    echo "" >/dev/null #just placeholder for now
  else
    RESP_DATA=`echo "$CURL_DATA"|tail -n 1`
    if [[ "x$DUMP_ARG" != "x" ]]; then
      #let's cut and show headers to stderr
      HEADERS=$(echo "$CURL_DATA"|head -n "-1")
      echo "$HEADERS" 1>&2
    fi

    TOTAL_TIME=`echo $RESP_DATA|awk '{print $1}'`
    CONNECT_TIME=`echo $RESP_DATA|awk '{print $2}'`
    echo "time:$curdate ttime:$TOTAL_TIME conntime:$CONNECT_TIME"
  fi

  sleep $INTERVAL
done
