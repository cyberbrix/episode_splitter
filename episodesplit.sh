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
midindex=unset
function=split

if [ -z "$*" ]
then
function=help
fi

for z in "$@"
do
case $z in
    -p=*)
    showdir="${z#*=}"
    shift # past argument=value
    ;;
    --split)
    function=split
    shift # past argument with no value
    ;;
    --index)
    function=index
    shift # past argument with no value
    ;;
    --indexfull)
    function=indexfull
    shift # past argument with no value
    ;;
    --test)
    function=testrun
    shift # past argument with no value
    ;;
    --examples)
    function=example
    shift # past argument with no value
    ;;
    -m=*)
    midindex="${z#*=}"
    shift # past argument=value
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
    function=help # unknown option
    ;;
esac
done

help_screen() {
    echo ""
    echo "    This script will split an episode into 2 parts, keeping the opening and closing credits."
    echo "    It will append the opening and closing to the appropriate missing piece."
    echo "    This is mostly designed because of many kids shows having 2 parts in 1 episode."
    echo "    but TVDB admins refuse to accept that and make each episode separate"
    echo ""
    echo "    Episodes must be named  \"Show Name - SxxExxExx.ext\""
    echo "    Example usage: ./episide_splitter.sh -p=\"/path/to/dir/\" [--test]"
    echo "    Arguments:"
    echo "    -p=\"/path/to/dir\"  Path to single or multiple files"
    echo "    must include include quotes and trailing / for directories"
    echo "    eg - \"/path/to/dir/\" or \"/path/to/file.exe\""
    echo "    --test  Enables test mode to output detected times and index numbers"
    echo "    --index  provides the index numbers for black parts the file/files. Cannot be used with test or split"
    echo "    --indexfull like index, but provides all the numbers, start,end,length of black parts"
    echo "    --split  default value. not needed Cannot be used with test or index"
    echo "    -m=x Index number for midpoint. You will pick this after running index"
    echo "         This only works on a single episode"    
    echo "    -b=x 0.0-0.9 black depth threshold. 0.0-0.2 should cut it. default 0.0"
    echo "    -l=x seconds for black duration 0.0-99.0. 0.3-0.7 should cut it. default 0.5"
    echo "    --examples  Displays examples of commands"
    echo "    Requires ffmpeg"
    echo "    Use test to see outputs. Should be 12 minimum numbers"
    echo "    Adjust black duration & threshold if you dont get 12 or more numbers"
    echo "    Will output files to current directory if permissions to write exist."
    echo "    Cuts may not be perfect. It is all best guess."
    echo ""
exit
    }


if [  "$function" = "example" ]
then
echo "    Examples of commands:"
echo ""
echo "    Split a folder of episodes:"
echo "    ./episode_splitter.sh \"/tvshows/show name/\""
echo ""
echo "    Split a single episode:"
echo "    ./episode_splitter.sh \"/tvshows/show name/show name.ext\""
echo ""
echo "    Split a single episode:"
echo "    ./episode_splitter.sh \"/tvshows/show name/show name.ext\""
echo ""
echo "    Test a folder to see how each episode would process:"
echo "    ./episode_splitter.sh \"/tvshows/show name/\" --test"
echo ""
echo "    List indexes of each black segment to force an episode split at a certain time point"
echo "    ./episode_splitter.sh \"/tvshows/show name/\" --index"
echo ""
echo "    List full index information of each black segment start, stop, duration"
echo "    ./episode_splitter.sh \"/tvshows/show name/\" --index"
echo ""
echo "    Override the default black depth. check ffmpeg documention"
echo "    ./episode_splitter.sh \"/tvshows/show name/\" -b=0.2"
echo ""
echo "    Override the black length. check ffmpeg documention"
echo "    ./episode_splitter.sh \"/tvshows/show name/\" -l=0.3"
fi

if [  "$function" = "help" ]
then
help_screen
fi



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

gettimes(){

ffmpeg -i "$1" -vf blackdetect=d=$2:pix_th=$3 -an -f null - 2>&1 | grep 'Duration\|blackdetect' | sed 's/.*black_start:\(\S*\).*black_end:\(\S*\).*black_duration:\(\S*\).*/\1 \2 \3/;s/Duration: / /;s/, start: / /;s/, bitrate: / /;s/ kb\/s/ /' | tr '\n' ' '
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

#check if midpoint is being used on a directory
if [ "$type" = "directory" ] && [ ! "$midindex" = "unset" ]
then
echo "Cannot set a midpoint on directory listing"
exit 1
fi


if [[ ! -x "$PWD" ]]
then
echo "cannot write to $PWD"
exit 1
fi


#Validate inputs - blackduration, depth, midpoint
bdpattern='^([0-9]){1,2}\.([0-9]){1,2}$'
[[ $blackduration =~ $bdpattern ]]
if [[ $? != 0 ]]
then
echo "black duration ($blackduration) not valid."
help_screen
exit 1
fi

btpattern='^0\.([0-9]){1,2}$'
[[ $blackthreshold =~ $bdpattern ]]
if [[ $? != 0 ]]
then
echo "black depth threshold ($blackthreshold) not valid."
help_screen
exit 1
fi

if [ ! "$midindex" = "unset" ]
then
indexpattern='^([0-9]){1,2}$'
[[ $midindex =~ $indexpattern ]]
if [[ $? != 0 ]]
then
echo "Index number ($midindex) not valid."
help_screen
exit 1
fi
fi

for show in "$showdir"*
do
filename=$(basename -- "$show")
extension="${filename##*.}"
filename="${filename%.*}"
showpattern='(.+)(S[0-9]+)(E[0-9]+)(E[0-9]+)(.*)'
[[ $filename =~ $showpattern ]]
if [[ $? != 0 ]]
then
echo "$show has an invalid file name"
echo "Episode must be named  \"Show Name - SxxExxExx.ext\""
continue
fi

showname="${BASH_REMATCH[1]}"
season="${BASH_REMATCH[2]}"
episode1="${BASH_REMATCH[3]}"
episode2="${BASH_REMATCH[4]}"


episodetimes=`gettimes "$show" $blackduration $blackthreshold`

#Create times into array
breaktimes=( $episodetimes )

#Count array elemets
breakcount=${#breaktimes[@]}

if [  "$function" = "index" ]
then
echo "$show"
v=3
while [ $v -lt $breakcount ]
do
echo -n "index $v: $(convertsecs ${breaktimes[v]}) "
((v=v+3))
done
echo ""
continue
fi

if [  "$function" = "indexfull" ]
then
echo "$show"
v=3
while [ $v -lt $breakcount ]
do
echo -n "index $v: $(convertsecs ${breaktimes[v]}) "
((v=v+1))
done
echo ""
continue
fi



#assign known elements to variables
totaltime=${breaktimes[0]}
starttime=${breaktimes[1]}
bitrate=${breaktimes[2]}

if [ $breakcount -lt 12 ]
then 
echo "$show - element count too low - episode not trimmable. Check black depth, then length"
continue
fi

#checks for proper elment count. must be interval of 3
n=`expr $breakcount % 3`
if [ $n -ne 0 ]
then
echo "$show - element count not multiple of 3 - episode not trimmable.Check black depth, then length"
continue
fi


#If breaks are correct, assign to final array
if [ $breakcount -eq 12 ]
then 
msg="Correct number of black segments found"
finalarray=("${breaktimes[@]}")
fi

#If array count not correct, assign known first 3 elements.

if [ $breakcount -gt 12 ]
then

msg="more than 3 black segments found"
#Find opening credits. First scene to be longer than 15 seconds

#Establishes start time of 0 seconds. Increments by 3, so skips over first 3 tokens
i=0
oplength=0
until [ $oplength -gt "15" ]
do 
((i=i+3))
oplength=`echo ${breaktimes[$i]} | sed 's/\([0-9]\+\)\.[0-9]\+/\1/'`
done


#Find ending credits. First scene from end to be longer than 15 seconds

#Establishes start time of 0 seconds. decriments by 3
totaltimesec=`echo $totaltime | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }' | sed 's/\([0-9]\+\)\.[0-9]\+/\1/'`
j=$breakcount
endlength=0
until [ $endlength -gt "15" ]
do 
((j=j-3))
endblackstart=`echo ${breaktimes[$j]} | sed 's/\([0-9]\+\)\.[0-9]\+/\1/'`
endlength=$((totaltimesec - endblackstart))
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

if [ ! "$midindex" = "unset" ]
then
midindexnum=$midindex
fi


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


if [  "$function" = "testrun" ]
then
echo "$show - $msg"
echo "Opening: 00:00:00 - $(convertsecs $openingstartblack), Ep1: 00:00:00 - $(convertsecs $ep1blackstart), Ep2: $(convertsecs $ep1blackend) - $totaltime, Closing: $(convertsecs $ep2blackend) - $totaltime"
echo ""
fi



if [  "$function" = "split" ]
then
echo "$show - $msg"
#Extract Opening Credits
ffmpeg -y -nostdin -loglevel quiet -ss 00:00:00 -i "$show" -t $openingstartblack "opening.$extension"
if [[ $? != 0 ]]
then
echo "error writing $show opening credits"
echo "moving on to next file"
continue
fi


#Extract Closing Credits
ffmpeg -y -nostdin -loglevel quiet -ss $ep2blackend -i "$show" "closing.$extension"
if [[ $? != 0 ]]
then
echo "error writing $show closing credits"
echo "moving on to next file"
continue
fi



#Create first segment. (Missing end credits)
ffmpeg -y -nostdin -loglevel quiet -ss 00:00:00 -i "$show" -t $ep1blackstart "firstep.$extension"
if [[ $? != 0 ]]
then
echo "error writing $show first segment"
echo "moving on to next file"
continue
fi


#Create second segment (Missing opening credits)
ffmpeg -y -nostdin -loglevel quiet -ss $ep1blackend -i "$show" "secondep.$extension"
if [[ $? != 0 ]]
then
echo "error writing $show second segment"
echo "moving on to next file"
continue
fi



#Create merge file
echo "file firstep.$extension" > merge.txt
echo "file closing.$extension" >> merge.txt

#Create first proper episode
ffmpeg -nostdin -loglevel quiet -f concat -i merge.txt "$showname$season$episode1.$extension"
if [[ $? != 0 ]]
then
echo "error writing $showname$season$episode1.$extension"
fi

#Create merge file
echo "file opening.$extension" > merge.txt
echo "file secondep.$extension" >> merge.txt

#Create second proper episode
ffmpeg -nostdin -loglevel quiet -f concat -i merge.txt "$showname$season$episode2.$extension"
if [[ $? != 0 ]]
then
echo "error writing $showname$season$episode2.$extension"
fi

rm "opening.$extension"
rm "closing.$extension"
rm "firstep.$extension"
rm "secondep.$extension"
rm merge.txt

fi

done
