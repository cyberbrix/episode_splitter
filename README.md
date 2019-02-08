This script will split an episode into 2 parts, keeping the opening and closing credits.
It will append the opening and closing to the appropriate missing piece.

This is mostly designed because of many kids shows having 2 parts in 1 episode.
but TVDB admins refuse to accept that and make each episode separate

Episodes must be named  "Show Name - SxxExxExx.ext" (more than 2 parts will not work at the moment)

Example usage: ./episide_splitter.sh -p="/path/to/dir/" [--test]

Arguments:

-p="/path/to/dir"  Path to single or multiple files

must include include quotes and trailing / for directories
eg - -p="/path/to/dir/" or -p="/path/to/file.exe"

--test  Enables test mode to output detected times and index numbers

--index  provides the index numbers for black parts the file/files. Cannot be used with test or split

--indexfull like index, but provides all the numbers, start,end,length of black parts

--split  default value. not needed Cannot be used with test or index

-m=x Index number for midpoint. You will pick this after running index (This only works on a single episode)

-b=x 0.0-0.9 black depth threshold. 0.0-0.2 should cut it. default 0.0

-l=x seconds for black duration 0.0-99.0. 0.3-0.7 should cut it. default 0.5

-c= [c or r] c is copy. r is remux. depending on your version of ffmpeg, you may either have to copy or remux
Copy may not cut perfectly on black spots, remux may not work if the version of ffmepg cant read the codec well

--examples  Displays examples of commands

Requires ffmpeg


Use test to see outputs. Should be 12 minimum numbers
Adjust black duration & threshold if you dont get 12 or more numbers
Will output files to current directory if permissions to write exist.
Cuts may not be perfect. It is all best guess.


MORE EXAMPLES:


Examples of commands:

Split a folder of episodes: (ffmpeg copy)
./episode_splitter.sh -p=\"/tvshows/show name/\" -c=c

Split a single episode: (ffmpeg remux)
./episode_splitter.sh -p=\"/tvshows/show name/show name.ext\" -c=r

Test a folder to see how each episode would process:
./episode_splitter.sh -p=\"/tvshows/show name/\" --test

List indexes of each black segment to force an episode split at a certain time point
./episode_splitter.sh -p=\"/tvshows/show name/\" --index -c=c

List full index information of each black segment start, stop, duration
./episode_splitter.sh -p=\"/tvshows/show name/\" --index  -c=c

Override the default black depth. check ffmpeg documention
./episode_splitter.sh -p=\"/tvshows/show name/\" -b=0.2  -c=r

Override the black length. check ffmpeg documention
./episode_splitter.sh -p=\"/tvshows/show name/\" -l=0.3 -c=c





Instructions
- Save as episode_splitter.sh
- chmod +x ./episode_splitter.sh to make it executable
- Run ./episode_splitter.sh with above options. It will save new files to the current directory
