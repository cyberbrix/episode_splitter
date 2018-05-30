#!/bin/bash

#This requires FFMPEG
#check if FFMPEG installed
if ! type ffmpeg &> /dev/null
then
echo "ffmpeg is not installed"
exit 1
fi


#default values
blackduration="0.5"
blackthreshold="0.0"

for z in "$@"
do
case $z in
    -p=*)
    showdir="${z#*=}"
    shift # past argument=value
    ;;
    --test)
    testvar=test
    shift # past argument with no value
    ;;
    -l=*)
    blackduration="${z#*=}"
    shift # past argument=value
    ;;
    -b=*)
    blackthreshold="${z#*=}"
    shift # past argument=value
    ;;
    *)
          # unknown option
    ;;
esac
done


help_screen() {
    echo ""
    echo "    This script will split an episode into 2 parts, keeping the opening and closing creditgs."
    echo "    It will append the opening and closing to the appropriate missing piece."
    echo "    This is mostly designed because of many kids shows having 2 parts in 1 episode."
    echo "    but TVDB admins refuse to accept that and make each episode separate"
    echo ""
    echo "    Example usage: ./episide_splitter.sh -p=\"/path/to/dir/\" [--test]"
    echo "    Arguments:"
    echo "    -p=\"/path/to/dir\"  What dir containts the show. include quotes and trailing /"
    echo "    --test  Enables test mode to output detected times and index numbers"
    echo "    -n=x Index number for midpoint. You will pick this after running test"
    echo "    -b=x 0.0-0.9 black depth threshold. 0.0-0.2 should cut it. default 0.0"
    echo "    -l=x seconds for black duration 0.0-99. 0.3-0.7 should cut it. default 0.5"
    echo "    Requires ffmpeg"
    echo "    Use test to see outputs. Should be 12 minimum numbers"
    echo "    Adjust black duration & threshold if you dont get 12 or more numbers"
    echo "    Will output files to current directory if permissions to write exist."
    echo "    Cuts may not be perfect. It is all best guess."
    echo ""
    }


convertsecs() {

if [[ $1 =~ \. ]];
then
  wholesec=$(echo ${1} | cut -f1 -d.)
  millisec=$(echo ${1} | cut -f2 -d.)
else
  wholesec=$(echo ${1} | cut -f1 -d.)
  millisec=0
fi

 ((h=${wholesec}/3600))
 ((m=(${wholesec}%3600)/60))
 ((s=${wholesec}%60))
 printf "%02d:%02d:%02d.$millisec\n" $h $m $s
}



if [[ -d "$showdir" ]]
 then
    type=directory
elif [[ -f "$showdir" ]]
 then
    type=file
else
echo "$showdir is not a valid file or path"
help_screen
exit 1
fi


if [[ ! -x "$PWD" ]]
then
echo "cannot write to $PWD"
exit 1
fi



for show in "$showdir"*
do
filename=$(basename -- "$show")
extension="${filename##*.}"
filename="${filename%.*}"
showpattern='(.+)(S[0-9]+)(E[0-9]+)(E[0-9]+)(.*)'
[[ $filename =~ $showpattern ]]
showname="${BASH_REMATCH[1]}"
season="${BASH_REMATCH[2]}"
episode1="${BASH_REMATCH[3]}"
episode2="${BASH_REMATCH[4]}"

echo $show


episodetimes=`ffmpeg -i "$show" -vf blackdetect=d=$blackduration:pix_th=$blackthreshold -an -f null - 2>&1 | grep 'Duration\|blackdetect' | sed 's/.*black_start:\(\S*\).*black_end:\(\S*\).*black_duration:\(\S*\).*/\1 \2 \3/;s/Duration: / /;s/, start: / /;s/, bitrate: / /;s/ kb\/s/ /' | tr '\n' ' '`

#Create times into array
breaktimes=( $episodetimes )

#Count array elemets
breakcount=${#breaktimes[@]}

#assign known elements to variables
totaltime=${breaktimes[0]}
starttime=${breaktimes[1]}
bitrate=${breaktimes[2]}

if [ $breakcount -lt 12 ]
then 
echo "element count too low"
continue
fi

#checks for proper elment count. must be interval of 3
n=`expr $breakcount % 3`
if [ $n -ne 0 ]
then
echo "element count not multiple of 3"
continue
fi


#If breaks are correct, assign to final array
if [ $breakcount -eq 12 ]
then 
echo "Correct number of black segments found"
finalarray=("${breaktimes[@]}")
fi

#If array count not correct, assign known first 3 elements.

if [ $breakcount -gt 12 ]
then

echo "more than 3 black segments found"
#Find opening credits. First scene to be longer than 15 seconds

#Establishes start time of 0 seconds. Increments by 3, so skips over first 3 tokens
i=0
oplength=0
until [ $oplength -gt "15" ]
do 
((i=i+3))
#echo "i: $i"
oplength=`echo ${breaktimes[$i]} | sed 's/\([0-9]\+\)\.[0-9]\+/\1/'`
#echo "oplength: $oplength"
done


#Find ending credits. First scene from end to be longer than 15 seconds

#Establishes start time of 0 seconds. decriments by 3
totaltimesec=`echo $totaltime | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }' | sed 's/\([0-9]\+\)\.[0-9]\+/\1/'`
j=$breakcount
endlength=0
until [ $endlength -gt "15" ]
do 
((j=j-3))
#echo "j: $j"
endblackstart=`echo ${breaktimes[$j]} | sed 's/\([0-9]\+\)\.[0-9]\+/\1/'`
endlength=$((totaltimesec - endblackstart))
#echo "endlength: $endlength"
done


#Find midpoint seconds
estmidpoint=$(( $totaltimesec / 2 ))

#extremely high 'diff' to have something to measure against for the first value
midpointdiff=9999999

#check each index between opening and closing creds to find midpoint
k=$(($i + 3))
while [ $k -lt $j ]; do

#black start time of current index
currtime=`echo ${breaktimes[k]} | sed 's/\([0-9]\+\)\.[0-9]\+/\1/'`

#Determine time diff, getting absolute value. (cheating by stripping the minus sign)
currtimediff=`echo $((estmidpoint - currtime)) | tr -d -`

if [[ $currtimediff -lt $midpointdiff ]]
then
midpointdiff=$currtimediff
midindexnum=$k
fi

k=$(($k + 3))
done

finalarray=( "${breaktimes[@]:0:3}" "${breaktimes[@]:$i:3}" "${breaktimes[@]:$midindexnum:3}" "${breaktimes[@]:$j:3}")
fi


openingstartblack=${finalarray[3]}
openingendblack=${finalarray[4]}
openingduration=${finalarray[5]}
ep1blackstart=${finalarray[6]}
ep1blackend=${finalarray[7]}
ep1blackdur=${finalarray[8]}
ep2blackstart=${finalarray[9]}
ep2blackend=${finalarray[10]}
ep2blackdur=${finalarray[11]}

#echo "$totaltime"
#echo "$starttime"
#echo "$bitrate"
#echo "$openingstartblack"
#echo "$openingendblack"
#echo "$openingduration"
#echo "$ep1blackstart"
#echo "$ep1blackend"
#echo "$ep1blackdur"
#echo "$ep2blackstart"
#echo "$ep2blackend"
#echo "$ep2blackdur"

if [  "$testvar" = "test" ]
then
echo "Opening: 00:00:00 - $(convertsecs $openingstartblack), Ep1: 00:00:00 - $(convertsecs $ep1blackstart), Ep2: $(convertsecs $ep1blackend) - $totaltime, Closing: $(convertsecs $ep2blackend) - $totaltime"
echo ""
fi



if [ ! "$testvar" = "test" ]
then
#Extract Opening Credits
ffmpeg -nostdin -loglevel quiet -ss 00:00:00 -i "$show" -t $openingstartblack -c copy "opening.$extension"

#Extract Closing Credits
ffmpeg -nostdin -loglevel quiet -ss $ep2blackend -i "$show" -c copy "closing.$extension"

#Create first segment. (Missing end credits)
ffmpeg -nostdin -loglevel quiet -ss 00:00:00 -i "$show" -t $ep1blackstart -c copy "firstep.$extension"

#Create second segment (Missing opening credits)
ffmpeg -nostdin -loglevel quiet -ss $ep1blackend -i "$show" -c copy "secondep.$extension"

#Create merge file
echo "file firstep.$extension" > merge.txt
echo "file closing.$extension" >> merge.txt

#Create first proper episode
ffmpeg -nostdin -loglevel quiet -f concat -i merge.txt -c copy "$showname$season$episode1.$extension"

#Create merge file
echo "file opening.$extension" > merge.txt
echo "file secondep.$extension" >> merge.txt

#Create second proper episode
ffmpeg -nostdin -loglevel quiet -f concat -i merge.txt -c copy "$showname$season$episode2.$extension"

rm "opening.$extension"
rm "closing.$extension"
rm "firstep.$extension"
rm "secondep.$extension"
rm merge.txt

fi

done
