#!/bin/sh

set -e

rm -rf input.txt define.txt

echo MIES_Include >> input.txt

# test UTF includes as well
if [ "$#" -gt 0 -a "$1" = "all" ]
then

  echo UTF_Main         >> input.txt
  echo UTF_HardwareMain >> input.txt

  # discard first parameter
  shift
fi

echo DEBUGGING_ENABLED >> define.txt
echo EVIL_KITTEN_EATING_MODE >> define.txt
echo BACKGROUND_TASK_DEBUGGING >> define.txt
echo THREADING_DISABLED >> define.txt
echo SWEEPFORMULA_DEBUG >> define.txt

./autorun-test.sh $@

exit 0
