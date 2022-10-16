#!/bin/bash

# ffmpeg is needed to run this script

# You can specify the output directory here or pass it in as a command argument (Type --help)
output_dir=''
input_dir='.'
overwrite_files='n'
delete_originals='n'

# Parse flags

SHORT_ARGS="hi:o:v"
LONG_ARGS=delete-originals,help,input:,output:,overwrite

PARSED=`getopt --options $SHORT_ARGS --longoptions $LONG_ARGS --name "$0" -- "$@"`

eval set --"$PARSED"

while true; do
	case "$1" in
		-h|--help) echo "VALID FLAGS"
			echo "--delete-originals		: After a GIF is successfully converted, the original is deleted."
			echo "-i | --input 	[directory_path]: Manually specify input directory to convert. If not given, uses the same directory this script resides in."
			echo "-o | --output 	[directory_path]: Manually specify output directory for files"
			echo "-v | --overwrite		: Makes ffmpeg overwrite files instead of skipping them"
			exit 0
			;;
		--delete-originals) delete_originals="y"
			shift
			;;
		-i|--input) input_dir="$2"
			shift 2
			;;
		-o|--output) output_dir="$2"
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
function convert_gif_to_h264() {
	# Arguments: File path, output directory, overwrite files, delete original

	# Remove the file path and file extension
	file_name="${1%.*}"
	file_name="${file_name##*/}"

	# Check if the converted video already exists
	target_path="$2/$file_name.mp4"
	if [ "$3" = "n" ]; then
		ls "$target_path" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "Converted GIF \"$file_name.mp4\" already exists! Skipping (Use -v to overwrite)"
			return 1;
		fi
	fi

	echo "Converting \""$1"\""
	ffmpeg -i "$1" -y -hide_banner -loglevel warning -stats -movflags faststart -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$target_path";

	exit_code=$?;
	if [ $exit_code -eq 255 ]; then
		echo "Terminating program."
		break;
	fi
	if [ ! $exit_code -eq 0 ]; then
		echo "An error has occurred. Please refer to any above output." >&2;
		exit 1;
	fi
}
export -f convert_gif_to_h264

# Search for GIFs
find "$input_dir" -regex '.*.\([Gg][Ii][Ff]\)$' -exec bash -c "convert_gif_to_h264 \"{}\" \"$output_dir\" $overwrite_files $delete_originals" \;

