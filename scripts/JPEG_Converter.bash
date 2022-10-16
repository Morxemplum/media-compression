#!/bin/bash

# ImageMagick is needed to run this script

# This program identifies any JPEG images and can either convert to AVIF, which
# has better compression and browser support, with good image quality; or JPEG-XL, 
# which converts losslessly and faster.

# You can specify the output directory here or pass it in as a command argument (Type --help)
output_dir=''
input_dir='.'
output_format="jxl" # avif for AVIF, jxl for JPEG-XL
overwrite_files='n'
delete_originals='n'
strip_metadata='n'

# Program constants
final_quality=60 # If AVIF is chosen, what should be the final quality

# Parse flags

SHORT_ARGS="f:hi:o:q:sv"
LONG_ARGS=delete-originals,format:,help,input:,output:,quality:,strip,overwrite

PARSED=`getopt --options $SHORT_ARGS --longoptions $LONG_ARGS --name "$0" -- "$@"`

eval set --"$PARSED"

while true; do
	case "$1" in
		-h|--help) echo "VALID FLAGS"
			echo "--delete-originals		: After an image is successfully converted, the original is deleted."
			echo "-f | --format	     <avif, jxl>: Specify the output's image format. Both are good for lossy images"
			echo "-i | --input 	[directory_path]: Manually specify input directory to convert. If not given, uses the same directory this script resides in."
			echo "-o | --output 	[directory_path]: Manually specify output directory for files"
			echo "-q | --quality		   [int]: If AVIF is chosen, determine the quality of the converted image (1-100)"
			echo "-s | --strip			: Strips metadata from an image, if there is any."
			echo "-v | --overwrite		: Overwrites images instead of skipping them"
			exit 0
			;;
		--delete-originals) delete_originals="y"
			shift
			;;
		-f|--format) output_format="$2"
			shift 2
			;;
		-i|--input) input_dir="$2"
			shift 2
			;;
		-o|--output) output_dir="$2"
			shift 2
			;;
		-q|--quality) final_quality=$2
			shift 2
			;;
		-s|--strip) strip_metadata="y"
			shift
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

if ! [[ $final_quality =~ $int_re ]]; then
	echo "Error: Quality must be an integer." >&2
	exit 1
fi

if [ $final_quality -lt 1 ] || [ $final_quality -gt 100 ]; then
	echo "Error: Quality ($final_quality) outside of valid range (1-100)." >&2
	exit 1
fi

if ! [[ $output_format =~ [Aa][Vv][Ii][Ff] ]] && ! [[ $output_format =~ [Jj][Xx][Ll] ]]; then
	echo "Error: Invalid output format $output_format. Format must be AVIF or JXL" >&2
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
function convert_jpeg() {
	# Arguments: File path, Output format, Final Quality, Output directory, Strip data, Overwrite, Delete Original

	# Remove the file path and file extension
	file_name="${1%.*}"
	file_name="${file_name##*/}"
	
	# Check if the converted video already exists
	target_path=""$4"/$file_name.$2"
	if [ "$6" = "n" ]; then
		ls "$target_path" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "Converted Image \"$file_name.$3\" already exists! Skipping (Use -v to overwrite)"
			return 1;
		fi
	fi
	
	echo "Converting \"$1\" to "$2""

	quality_string=""
	strip_string=""
	if [[ $2 =~ [Aa][Vv][Ii][Ff] ]]; then
		quality_string="-quality $3"
	fi
	if [ "$5" = "y" ]; then
		strip_string="-strip"
	fi

	magick convert "$1" $quality_string $strip_string "$target_path"
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
		rm "$1"
	fi

	return 0
}
export -f convert_jpeg

# Search for any JPEGs
find "$input_dir" -regex '.*.\([Jj][Pp][Gg]\|[Jj][Pp][Ee][Gg]\)$' -exec bash -c "convert_jpeg \"{}\" $output_format $final_quality \"$output_dir\" $strip_metadata $overwrite_files $delete_originals" \;

