#!/bin/bash

# Variables to be set depending on preferences
REPOCONF="imgurRepo2.conf"
FIXSUFFIX=true
REMOVEDUPES=true
GENWEBPAGE=true
BAREBONES=false

# Checks if program fdupes is available
# if it is not, then exit prematurely
function checkRemoveDupes(){
  if [ "$REMOVEDUPES" = true ]; then
    if ! [ -x "$(which fdupes)" ]; then
      echo "ERROR: fdupes is not installed or executable.  Exiting now."
      exit
    fi
  fi
}

# Check if album exists in ../changelog
# If it does not exist, add it for keeping history
function checkInChangelog(){
  ALBUM="$1"
  DIR="${PWD##*/}"

  if ! [ -e ../changelog ]; then
    echo "Creating changelog to keep history of albums"
    echo "Albums:" >> ../changelog
  fi
  if ! grep -q -F "$ALBUM - $DIR" ../changelog; then
    echo "Adding $ALBUM in $DIR to ../changelog"
    echo "$(date +%Y-%m-%d-%H-%M-%S) - $ALBUM - $DIR" >> ../changelog
  fi
}

# Creates a persistent album-links file for fast checking
function checkForImgurLinksFile(){
  ALBUM="$1"

  if ! [ -e ./".$ALBUM-links.txt" ]; then
    echo "Creating .$ALBUM-links.txt"
    echo "Links:" >> ./".$ALBUM-links.txt"
  fi
}

# Output the true file suffix of an image
function checkFileSuffix(){
  EXT="$(file -b "$1" | cut -d " " -f1)"

  # A hack made because there is no flag in the
  # command `file' to just output the suffix
  if [ "$EXT" = "JPEG" ]; then
    echo "jpg"
  elif [ "$EXT" = "PNG" ]; then
    echo "png"
  elif [ "$EXT" = "GIF" ]; then
    echo "gif"
  else
    echo "$EXT"
  fi
}

# Check if a file has the correct suffix
# If it does not, then rename it to fix it
function fixFileSuffix(){
  FILE="$1"
  FILENAME="$(echo "$FILE" | cut -d "." -f1)"
  FILESUFFIX="$(echo "$FILE" | cut -d "." -f2)"
  REALFILESUFFIX="$(checkFileSuffix "$FILE")"

  if [ "$REALFILESUFFIX" != "$FILESUFFIX" ]; then
    echo "Correcting suffix of $FILE to $REALFILESUFFIX"
    mv "$FILE" "$FILENAME.$REALFILESUFFIX"
  fi
}

# Use fdupes to check for and remove duplicate files
# within an image folder which is useful when many albums
# are being compiled
function checkForAndRemoveDuplicates(){
  DIRECTORY="$1"

  checkRemoveDupes
  echo "Looking for duplicates in album $DIRECTORY"
  yes 1 | fdupes -rd "$DIRECTORY"
  echo "Deduplication finished for album $DIRECTORY"
}

# Scrape for an online imgur album for links and place
# them within a temp file 
function imgurLinksDownload(){
  ALBUM="$1"

  wget -q -O - "http://imgur.com/a/$ALBUM/layout/blog" |
  grep "<a href=\"//i.imgur.com/" |
  cut -d \" -f2 |
  sed 's/.*/http:&/'
}

# Create a minimal web page to view albums that have been
# used in the creation of an offline imgur repository 
function generateOnlineAlbumPage(){
  CONFIG="$1"
  NAME="${PWD##*/}"

  echo "Generating web page for browsing online imgur albums"

  echo "<!DOCTYPE html>" > ./"$NAME.html"
  echo "<html lang=\"en\">" >> ./"$NAME.html"
  echo "<head>" >> ./"$NAME.html"
  echo "<meta charset=\"utf-8\">" >> ./"$NAME.html"
  echo "<title>$NAME</title>" >> ./"$NAME.html"
  echo "</head>" >> ./"$NAME.html"
  echo "<body>" >> ./"$NAME.html"

  echo "$CONFIG" | while read LINE; do
    if echo "$LINE" | grep -q "|"; then
      DIRECTORY="$(echo "$LINE" | cut -d "|"  -f1 | sed 's| *$||g')"
      ALBUMLIST="$(echo "$LINE" | cut -d "|"  -f2)"
    elif echo "$LINE" | grep -q "-"; then
      DIRECTORY="$(echo "$LINE" | cut -d "-"  -f1 | sed 's| *$||g')"
      ALBUMLIST="$(echo "$LINE" | cut -d "-"  -f2)"
    fi

    echo "<p>$DIRECTORY<p>"
    echo "<ul>"
    for ALBUM in $ALBUMLIST; do
      echo "<li><a href=\"http://imgur.com/a/$ALBUM\">http://imgur.com/a/$ALBUM</a>"
    done
    echo "</ul>"
  done >> ./"$NAME.html"
  echo -e "</body>\n</html>" >> ./"$NAME.html"
}

function generateBareBonesPackage(){
  CONFIG="$1"
  NAME="${PWD##*/}"

  echo "Generating barebones package"
  mkdir -p ./".$NAME"

  echo "$CONFIG" | while read LINE; do
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
  tar czf "$NAME-$(date +%Y-%m-%d-%H-%M-%S).tgz" ".$NAME"/
  rm -rf ./".$NAME"
  echo "Package generated"
}

# Check for fdupes before beginning the main task
# of updating the imgur repository
checkRemoveDupes

CONFIG="$(cat "$REPOCONF" | awk '{$1=$1}1')"

echo "$CONFIG" | while read LINE; do
  # Configure ORDERALBUM, ALBUMLIST, and DIRECTORY
  # below based upon the config syntax of `-' or `|'
  if echo "$LINE" | grep -q "|"; then
    ORDERALBUM=true
    DIRECTORY="$(echo "$LINE" | cut -d "|"  -f1 | sed 's| *$||g')"
    ALBUMLIST="$(echo "$LINE" | cut -d "|"  -f2)"
  elif echo "$LINE" | grep -q "-"; then
    ORDERALBUM=false
    DIRECTORY="$(echo "$LINE" | cut -d "-"  -f1 | sed 's| *$||g')"
    ALBUMLIST="$(echo "$LINE" | cut -d "-"  -f2)"
  fi
  mkdir -p "$DIRECTORY"
  echo "Updating album $DIRECTORY"
  cd "$DIRECTORY"
  LINKTOTAL="0"
  for ALBUM in $ALBUMLIST; do
    NEWIMAGES=""
    checkInChangelog "$ALBUM"
    checkForImgurLinksFile "$ALBUM"
    
    # If any links do not exist in the album-links
    # file then append it to NEWIMAGES
    for IMAGE in $(imgurLinksDownload "$ALBUM"); do
      if ! grep -q "$IMAGE" ./".$ALBUM-links.txt"; then
        NEWIMAGES+="$IMAGE "
      fi
    done
    
    ITERATOR="0"
    FILECOUNT="$(ls | wc -l)"
    LINKCOUNT="$(echo "$NEWIMAGES" | wc -w)"
    LINKTOTAL="$(($LINKCOUNT + $LINKTOTAL))"
    for IMAGE in $NEWIMAGES; do
      ITERATOR="$((ITERATOR + 1))"
      FILECOUNT="$(($FILECOUNT + 1))"
      FILE="$(echo "$IMAGE" | cut -d/ -f4)"
      if [ "$ORDERALBUM" = true ]; then
        FILE="$FILECOUNT - $FILE"
      fi

      echo -n "$ITERATOR of $LINKCOUNT in $ALBUM: $IMAGE .."
      wget -O "$FILE" -q -c "$IMAGE"
      echo ".. Finished"
      echo "$(date +%Y-%m-%d-%H-%M-%S) - $IMAGE" >> ./".$ALBUM-links.txt"

      # Check file suffix if FIXSUFFIX is enabled and fix it if
      # the it is not correct
      if [ "$FIXSUFFIX" = true ]; then
        fixFileSuffix "$FILE"
      fi
    done
  done
  cd -
  # Check for duplicates unless ORDERALBUM is set to true
  # since removing duplicates can break album ordering
  if [ "$REMOVEDUPES" = true ]; then
    if [ "$LINKTOTAL" -gt "0" ] && [ "$ORDERALBUM" = false ]; then
      checkForAndRemoveDuplicates "$DIRECTORY"
    fi
  fi
  echo "Update for album $DIRECTORY complete"
  echo
done

if [ "$GENWEBPAGE" = true ]; then
  generateOnlineAlbumPage "$CONFIG"
fi

# Should be left disabled unless needed as it can take a few
# moments to run
if [ "$BAREBONES" = true ]; then
  generateBareBonesPackage "$CONFIG"
fi

echo "Update complete!"
