This script will split an episode into 2 parts, keeping the opening and closing credits.
It will append the opening and closing to the appropriate missing piece.

This is mostly designed because of many kids shows having 2 parts in 1 episode.
but TVDB admins refuse to accept that and make each episode separate

Episodes must be named  "Show Name - SxxExxExx.ext" (more than 2 parts will not work at the moment)

Example usage: ./episide_splitter.sh -p="/path/to/dir/" [--test]

Arguments:

-p="/path/to/dir"  Path to single or multiple files

must include include quotes and trailing / for directories
eg - "/path/to/dir/" or "/path/to/file.exe"

--test  Enables test mode to output detected times and index numbers
--index  provides the index numbers for black parts the file/files. Cannot be used with test or split
--indexfull like index, but provides all the numbers, start,end,length of black parts
--split  default value. not needed Cannot be used with test or index
-m=x Index number for midpoint. You will pick this after running index (This only works on a single episode)
-b=x 0.0-0.9 black depth threshold. 0.0-0.2 should cut it. default 0.0
-l=x seconds for black duration 0.0-99.0. 0.3-0.7 should cut it. default 0.5
--examples  Displays examples of commands

Requires ffmpeg


Use test to see outputs. Should be 12 minimum numbers
Adjust black duration & threshold if you dont get 12 or more numbers
Will output files to current directory if permissions to write exist.
Cuts may not be perfect. It is all best guess.


MORE EXAMPLES:


Split a folder of episodes:
./episode_splitter.sh "/tvshows/show name/"

Split a single episode:
./episode_splitter.sh "/tvshows/show name/show name.ext"

Split a single episode:
./episode_splitter.sh "/tvshows/show name/show name.ext"

Test a folder to see how each episode would process:
./episode_splitter.sh "/tvshows/show name/" --test

List indexes of each black segment to force an episode split at a certain time point
./episode_splitter.sh "/tvshows/show name/" --index

List full index information of each black segment start, stop, duration
./episode_splitter.sh "/tvshows/show name/" --index

Override the default black depth. check ffmpeg documention
./episode_splitter.sh "/tvshows/show name/" -b=0.2

Override the black length. check ffmpeg documention
./episode_splitter.sh "/tvshows/show name/" -l=0.3


Instructions
- Save as episodesplit.sh
- chmod +x episodesplit.sh to make it executable
- Run ./episodesplit.sh with above options. It will save new files to the current directory
