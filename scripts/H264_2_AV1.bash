#!/bin/bash

# ffprobe and ffmpeg are needed to run this script
# This program identifies any videos using the h.264 codec, scrapes the metadata to find the exact bitrate of the video, 
# and reduces it to where AV1 can preserve quality. 

# You can specify the output directory here or pass it in as a command argument (Type --help)
output_dir=''
input_dir='.'
overwrite_files='n'
delete_originals='n'

# Program constants
# The codec that is used is SVT-AV1
av1_preset=8
bitrate_multiplier=60

# Ideal bitrate is a constant that is used as an upper ceiling for bitrate.
# Having a video higher than this produces diminishing returns for visual quality. Increase this at your own risk!
# This bitrate goes 1:1 on a 1920x1080 video @ 60 FPS
ideal_bitrate=5000000
ideal_pix_mult=$(echo "scale=3; $ideal_bitrate / (1920 * 1080)" | bc -l)


# Parse flags

SHORT_ARGS="hi:m:o:p:v"
LONG_ARGS=delete-originals,help,input:,multiplier:,output:,preset:,overwrite

PARSED=`getopt --options $SHORT_ARGS --longoptions $LONG_ARGS --name "$0" -- "$@"`

eval set --"$PARSED"

while true; do
	case "$1" in
		-h|--help) echo "VALID FLAGS"
			echo "--delete-originals		: After a video is successfully converted, the original is deleted."
			echo "-i | --input 	[directory_path]: Manually specify input directory to convert. If not given, uses the same directory this script resides in."
			echo "-m | --multiplier	   [int]: Multiplier of the new video from the base video (0-100) (Default: 60)"
			echo "-o | --output 	[directory_path]: Manually specify output directory for files"
			echo "-p | --preset		   [int]: Sets the preset value for the SVT-AV1 codec (0-12) (Default: 8)"
			echo "-v | --overwrite		: Makes ffmpeg overwrite files instead of skipping them"
			exit 0
			;;
		--delete-originals) delete_originals="y"
			shift
			;;
		-i|--input) input_dir="$2"
			shift 2
			;;
		-m|--multiplier) bitrate_multiplier=$2
			shift 2
			;;
		-o|--output) output_dir="$2"
			shift 2
			;;
		-p|--preset) av1_preset=$2
			shift 2
			;;
		-v|--overwrite) overwrite_files="y"
			shift
			;;
		--)
			shift
			break
			;;
		*) echo "Improper arguments! Type in --help for help." 
			exit 1
			;;
	esac
done


# Some more sanity checks

int_re="^[+-]?[0-9]+$"

if ! [[ $av1_preset =~ $int_re ]]; then
	echo "Error: AV1 Preset must be an integer." >&2
	exit 1
fi

if [ $av1_preset -lt 0 ] || [ $av1_preset -gt 12 ]; then
	echo "Error: AV1 Preset ($av1_preset) outside of valid range (0-12)." >&2
	exit 1
fi

if ! [[ $bitrate_multiplier =~ $int_re ]]; then
	echo "Error: Bitrate multiplier must be an integer." >&2
	exit 1
fi

if [ $bitrate_multiplier -lt 0 ] || [ $bitrate_multiplier -gt 100 ]; then
	echo "Error: Bitrate multiplier outside of valid range (0-100)"
	exit 1
fi

# Check the directories exist

if [ "$output_dir" = "" ]; then
	echo "-o: No output directory specified" >&2
	echo "Type in --help for help" >&2
	exit 1
fi

if [ ! -d "$input_dir" ]; then
	echo "Input directory does not exist. Terminating." >&2
	exit 1
fi

if [ ! -d "$output_dir" ]; then
	echo "Output directory does not exist. Creating."
	mkdir "$output_dir"
	if [ ! -d "$output_dir" ]; then
		echo "Failed to make output directory. Insufficient permissions?"
		exit 1
	fi
fi 

shopt -s extglob
function convert_to_av1() {
	# Arguments: File path, AV1 preset, bitrate multiplier, ideal pixel multiplier, output directory, overwrite files, delete original

	# Remove the file path and file extension
	file_name="${1%.*}"
	file_name="${file_name##*/}"
	
	# Check if the converted video already exists
	target_path="$5/$file_name [AV1].mkv"
	if [ "$6" = "n" ]; then
		ls "$target_path" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "Converted Video \"$file_name [AV1].mkv\" already exists! Skipping (Use -v to overwrite)"
			return 1;
		fi
	fi
	
	# Use ffprobe and grab the video's metadata, including codec and bitrate
	ffprobe -hide_banner -loglevel warning -i "$1" -print_format ini -show_format -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate -sexagesimal -o metadata.tmp.txt

	exit_code=$?
	if [ $exit_code -eq 255 ]; then
		echo "Terminating program."
		exit 2
	fi
	if [ ! $exit_code -eq 0 ]; then
		echo "An error has occurred. Please refer to any above output." >&2
		exit 1
	fi

	video_codec=$(grep "codec_name" metadata.tmp.txt)
	video_codec=${video_codec:11}
	if [[ ! video_codec="h264" ]]; then
		echo "Video \""$1"\" is not encoded in H.264. Skipping."
		return 1;
	fi

	video_bitrate=$(grep "bit_rate" metadata.tmp.txt)
	video_bitrate=${video_bitrate:9}
	video_width=$(grep "width=" metadata.tmp.txt)
	video_width=${video_width:6}
	video_height=$(grep "height=" metadata.tmp.txt)
	video_height=${video_height:7}
	video_rfps=$(grep "r_frame_rate=" metadata.tmp.txt)
	video_rfps=${video_rfps:13}
	video_fps=$(echo "scale=4; "$video_rfps"" | bc -l)
	video_duration=$(grep "duration=" metadata.tmp.txt | sed 's/\\//g')
	video_duration=${video_duration:9}

	rm metadata.tmp.txt

	echo "Converting \"$1\""
	echo "	Frame Size: "$video_width"x"$video_height""
	echo "	Bitrate: $video_bitrate bits/s"
	echo "	Frame Rate: "$video_rfps" ($video_fps)"
	echo "	Duration: $video_duration"

	new_bitrate=$(echo "$video_bitrate * $3 / 100" | bc)

	# Calculate the ideal bitrate for a video with these stats
	# The FPS has an affect on the result that respects video streaming websites
	fps_bit_mult=$(echo "0.0134 * $video_fps + 0.196" | bc)
	video_ideal=$(echo "$video_width * $video_height * $4 * $fps_bit_mult / 1" | bc)

	new_bitrate=$(( new_bitrate > video_ideal ? video_ideal : new_bitrate ))
	if [ $new_bitrate -eq $video_ideal ]; then
		echo "	Bitrate for this video will be capped to $video_ideal bits/second"
	fi

	ffmpeg -i "$1" -y -hide_banner -loglevel warning -stats -c:v libsvtav1 -preset $2 -b:v $new_bitrate -c:a libopus -b:a 96K -map 0 "$target_path";
	
	exit_code=$?
	if [ $exit_code -eq 255 ]; then
		echo "Terminating program."
		exit 2
	fi
	if [ ! $exit_code -eq 0 ]; then
		echo "An error has occurred. Please refer to any above output." >&2
		exit 1
	fi

	# Delete original?
	if [[ "$7" = "y" ]]; then
		echo "Deleting original"
		rm "$1"
	fi

	echo ""
	return 0
}
export -f convert_to_av1

# Search for any video files. These containers should contain h264
find "$input_dir" -regex '.*.\(avi\|flv\|mkv\|mov\|mp4\|wmv\)$' -exec bash -c "convert_to_av1 \"{}\" $av1_preset $bitrate_multiplier $ideal_pix_mult \"$output_dir\" $overwrite_files $delete_originals" \;

