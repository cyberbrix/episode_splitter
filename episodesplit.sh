#!/bin/bash

#This requires FFMPEG

showdir=$1
testvar=$2


#check if JQ installed
if ! type ffmpeg1 &> /dev/null
then
echo "ffmpeg is not installed"
exit 1
fi

if [ "$showdir" = "test" ]
then
testvar=test
fi


#insert show path here to override. Uncomment the next line
#showdir="/path/to/show/"


help_screen() {
    echo ""
    echo "    This script will split an episode into 2 parts, keeping the opening and closing creditgs."
    echo "    It will append the opening and closing to the appropriate missing piece."
    echo "    This is mostly designed because of many kids shows having 2 parts in 1 episode."
    echo "    but TVDB admins refuse to accept that and make each episode separate"
    echo ""
    echo "    Usage: ./episide_splitter.sh \"/path/to/dir/\" [test]"
    echo "    Requires ffmpeg"
    echo "    Use Test to see outputs. Should be 12 minimum numbers"
    echo "    Adjust blackdetect & pix_th if you dont get 12 or more numbers"
    echo "    Point to a source directoy. Must have \/\" at end of path."
    echo "    Will output files to current directory if permissions to write exist."
    echo "    Cuts may not be perfect. It is all best guess."
    echo ""
    }

#if [[ "$showdir" = "?" ]]
#then
#echo "Directory is not valid"
#help_screen
#exit 1
#fi




if [[ ! -d "$showdir" ]]
then
echo "Directory is not valid"
help_screen
exit 1
fi

if [[ ! -x "$PWD" ]]
then
echo "cannot write to $PWD"
exit 1
fi


if [ "$testvar" = "test" ]
then
##Run this to test out the show in question to see how detection goes. 12 numbers is perfect. less than 12 is bad.
for show in "$showdir"*
do
echo $show
ffmpeg -i "$show" -vf blackdetect=d=0.5:pix_th=.1 -an -f null - 2>&1 | grep 'Duration\|blackdetect' | sed 's/.*black_start:\(\S*\).*black_end:\(\S*\).*black_duration:\(\S*\).*/\1 \2 \3/;s/Duration: / /;s/, start: / /;s/, bitrate: / /;s/ kb\/s/ /' | tr '\n' ' '
echo -n ""
done
echo "There should be more than 12 elements. If not, adjust the black detection in the script"
exit 0
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

#detect episodes. you should run the next line on a single episode to test detection.
#adjust d=0.5 to be how long the black spaces between shows are.
#adjust pix_th=.1 from 0.0 to 0.2 to change black detection. Different shows work differently.

episodetimes=`ffmpeg -i "$show" -vf blackdetect=d=0.5:pix_th=.1 -an -f null - 2>&1 | grep 'Duration\|blackdetect' | sed 's/.*black_start:\(\S*\).*black_end:\(\S*\).*black_duration:\(\S*\).*/\1 \2 \3/;s/Duration: / /;s/, start: / /;s/, bitrate: / /;s/ kb\/s/ /' | tr '\n' ' '`

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
echo "correct num of breaks"
finalarray=("${breaktimes[@]}")
fi

#If array count not correct, assign known first 3 elements.

if [ $breakcount -gt 12 ]
then

echo "more than 3 breaks"
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
done
