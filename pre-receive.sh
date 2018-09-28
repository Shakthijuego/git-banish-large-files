#!/bin/bash -eu
set -o pipefail

nullsha="0000000000000000000000000000000000000000"
maxsize=5
maxbytes=$(( $maxsize * 1024 * 1024 ))
status=0

# Read stdin for ref information
while read oldref newref refname; do
  # Skip branch deletions
  if [ "$newref" = "$nullsha" ]; then
    continue
  fi

  # Set oldref to HEAD if this is branch creation
  if [ "$oldref" = "$nullsha" ]; then
    oldref="HEAD"
  fi

  # Find large objects
  for file in $(git rev-list --objects ${oldref}..${newref} | \
      git cat-file --batch-check='%(objectname) %(objecttype) %(objectsize) %(rest)' | \
      awk -v maxbytes="$maxbytes" '$3 > maxbytes { print $4 }'); do

    # Display error header if this is the first offending file
    if [ "$status" -eq "0" ]; then
      status=1
      echo "-------------------------------------------------------------------------"
      echo "Your push was rejected because it contains files larger than $maxsize MB."
      echo "Please discuss with the Admin the best place to store these files."
      echo "You might want to consider using https://git-lfs.github.com/ instead."
      echo "-------------------------------------------------------------------------"
      echo "Offending files:"
    fi

    echo " - $file"
  done

  excludeExisting="--not --all"


  # Check for new branch or tag
  if [ "$oldref" = "$nullsha" ]; then
    span=`git rev-list $newref $excludeExisting`
  else
    span=`git rev-list $oldref..$newref $excludeExisting`
  fi

  for COMMIT in $span;
  do
    for FILE  in `git log -1 --name-only --pretty=format:'' $COMMIT`;
    do
      case $FILE in
      *.apk|*.ipa)
      status=1
      echo "-------------------------------------------------------------------------"
      echo "Your push was rejected because it contains restricted file type "
      echo "Please donot commit build files(ipa/apk) to git "
      echo "You might want to consider adding build folder in ignore list. Contact admin for more info"
      echo "-------------------------------------------------------------------------"
      echo "Offending files:"
        ;;
      esac
      echo -n $FILE
    done
  done

  

done

if [ "$status" -ne "0" ]; then echo; fi
exit $status
