#!/bin/bash

URL="http://localhost:3000/issues/1"

COUNT=10

times=()

for i in $(seq 1 $((COUNT + 1))); do
  result=$(curl -s -o /dev/null -w "time_total: %{time_total}, http_code: %{http_code}" $URL)
  time=$(echo $result | awk -F', ' '{print $1}' | awk -F': ' '{print $2}')
  http_code=$(echo $result | awk -F', ' '{print $2}' | awk -F': ' '{print $2}')

  if [[ "$http_code" -ne 200 ]]; then
    echo "Error: HTTP status code is $http_code. Exiting."
    exit 1
  fi

  if [[ $i -eq 1 ]]; then
    echo "Initial run (excluded from stats): $result"
    sleep 1.5
    continue
  fi

  times+=($time)
  echo "Run $((i - 1)): $result"

  sleep 1.5
done

sum=0
for t in "${times[@]}"; do
  sum=$(echo "$sum + $t" | bc)
done
average=$(echo "scale=6; $sum / $COUNT" | bc)

sorted_times=($(printf '%s\n' "${times[@]}" | sort -n))
if (( $COUNT % 2 == 0 )); then
  mid1=${sorted_times[$((COUNT / 2 - 1))]}
  mid2=${sorted_times[$((COUNT / 2))]}
  median=$(echo "scale=6; ($mid1 + $mid2) / 2" | bc)
else
  median=${sorted_times[$((COUNT / 2))]}
fi

echo "Average time_total: $average"
echo "Median time_total: $median"
