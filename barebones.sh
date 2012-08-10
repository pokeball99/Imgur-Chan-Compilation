#!/bin/bash

CONFIG="imgurRepo.conf"
NAME="${PWD##*/}"
mkdir -p ./".$NAME"

cat ./$CONFIG | while read LINE; do
  if echo "$LINE" | grep -q "|"; then
    DIRECTORY="$(echo "$LINE" | cut -d "|" -f1 | sed 's| *$||g')"
    ALBUMLIST="$(echo "$LINE" | cut -d "|"  -f2)"
  elif echo "$LINE" | grep -q "-"; then
    DIRECTORY="$(echo "$LINE" | cut -d "-" -f1 | sed 's| *$||g')"
    ALBUMLIST="$(echo "$LINE" | cut -d "-" -f2)"
  fi

  mkdir -p ./".$NAME"/"$DIRECTORY"

  for ALBUM in $ALBUMLIST; do
    echo "Links: " > ./".$NAME"/"$DIRECTORY"/".$ALBUM-links.txt"
    FILELIST="$(grep "http://i.imgur.com/" ./"$DIRECTORY"/".$ALBUM-links.txt" | cut -d\/ -f4)"
    for LINK in $FILELIST; do
      if ! [ -e ./"$DIRECTORY"/"$LINK" ]; then
        echo "http://i.imgur.com/$LINK"
      fi
    done >> ./".$NAME"/"$DIRECTORY"/".$ALBUM-links.txt"
  done
done

cp ./"$CONFIG" ./imgurRepoSync.sh ./README.md ./changelog ./".$NAME" 

tar cvzf "$NAME-$(date +%Y-%m-%d-%H-%M-%S).tgz" ".$NAME"/

rm -rf ./".$NAME"
