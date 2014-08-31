#!/bin/bash

#--------------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------------#
#-----SCRIPT CONFIG--------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------------#

script="$0"
if [[ "$(echo "/$(ls -ld $0 | cut -d '/' -f 2-)" | grep -)" != "" ]]; then
	script=$(echo "/$(ls -ld $0 | cut -d '/' -f 2-)" | grep - | cut -d '>' -f 2- | cut -c 2-)
fi
script_directory=$(echo `dirname $script`)
movie_or_tv="$1"
name_of_file="$2"

# Script must have two arguments or it will fail
if [[ -z "$2" ]]; then echo "
Please ensure you append a file type and the file location you wish to process to the script.
" >&2 && exit; fi

# Search for and source a config file
configfile="$script_directory/media_server.cfg"
if [[ -f "$configfile" ]]; then echo "
Found config file:		$configfile
" >&2 && source "$configfile"; else echo "
Could not find config file. Are all the relevant scripts and files in the right directory?
" >&2 && exit 1; fi

#--------------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------------#
#-----FUNCTIONS------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------------#

### Checks the OS being used
check_os () {
	if [ "$(uname)" = "Darwin" ]; then
		OS="Mac"
		HandBrakeCLI="$handbrake_location/HandBrakeCLI"
	elif [ "$(uname)" = "Linux" ]; then
		OS="Linux"
		HandBrakeCLI=$(whereis HandBrakeCLI | cut -d ' ' -f 2)
	else
		echo "Your Operating System is not supported. Please request support via GitHub. If you feel there is an issue, please post it on GitHub."
		exit
	fi
}

# Gets the first audio track number which is in the desired language
get_lang () {
input_file="$1"
language_to_find="$2"

# mediainfo must be installed for the script to work

no_tracks=$(mediainfo "$input_file" | grep "Language" | cut -d':' -f 2 | tr -d ' ')
no_video=$(mediainfo "$input_file" | grep "Video" | grep -v "Format" | grep -v "Codec")
no_audio=$(mediainfo "$input_file" | grep "Audio" | grep -v "Format" | grep -v "Codec")

oldIFS=$IFS
IFS=$'\n' 
read -rd '' -a track_array <<<"$no_tracks"
read -rd '' -a video_array <<<"$no_video"
read -rd '' -a audio_array <<<"$no_audio"
IFS=$oldIFS

if [[ ${#audio_array[@]} -gt 1 ]]; then
	starting_track=${#video_array[@]}
	ending_track=$((${#video_array[@]}+${#audio_array[@]}-1))

	for i in $(eval echo {$starting_track..$ending_track})
	do
		if [[ -z "$audio_track" ]]; then
	    	if [[ "${track_array[i]}" == "$language_to_find" ]] ; then
	    		audio_track="$(($i+1-${#video_array[@]}))"
	    	fi
		fi
	done
	
	if [[ -z "$audio_track" ]]; then
		audio_track="1"
	fi
else
	audio_track="1"
fi
}

# Analyse how many formats and which formats should be used when transcoding
format_output () {
input_file="$1"
if [[ "$movie_or_tv" == "tv" ]]; then
	format_number="0"
elif [[ "$movie_or_tv" == "movie" ]]; then
file_width="$(mediainfo "$input_file" | grep "Width" | cut -d ":" -f 2- | awk -F 'pixels' '{print $1}' | tr -d ' ')"
case "$file_width" in
	
esac
fi
}

# Transcode a file with HandBrakeCLI with the formats specified in argument 2 (1,2 or 1,3 for example) and then rename using Filebot before deleting the original file
transcode_with_handbrake_and_filebot () {
input_file="$1"
format_number="$2"
basename=$(basename "$1")
filename=${basename%.*}
get_lang "$1" "English"


format_number=$(echo "$format_number" | tr -d ' ')
case "$i" in
0)
	transcode_settings="$transcode_zer"
;;
1)
	transcode_settings="$transcode_one"
;;
2)
	transcode_settings="$transcode_two"
;;
	3)
	transcode_settings="$transcode_thr"
;;
esac

if [[ "$format_number" != "" ]]; then
output_format="$temp_loc/$filename""_$format_number.mkv"	
handbrake_command="$HandBrakeCLI -i \"$1\" -o \"$output_format\" $transcode_settings -a $audio_track"
echo $handbrake_command >&2
# eval $handbrake_command 
fi
# rm "$1"
}


##
##	SCRIPT START
##

check_os

transcode_with_handbrake_and_filebot "$name_of_file" "$format_number"