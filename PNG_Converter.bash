#!/bin/bash

# ImageMagick is needed to run this script

# This program identifies any PNG images and converts them to WebP, 
# which has better lossless compression than PNG.

# You can specify the output directory here or pass it in as a command argument (Type --help)
output_dir=''
input_dir='.'
overwrite_files='n'
delete_originals='n'
strip_metadata='n'

# Parse flags

SHORT_ARGS="hi:o:sv"
LONG_ARGS=delete-originals,help,input:,output:,strip,overwrite

PARSED=`getopt --options $SHORT_ARGS --longoptions $LONG_ARGS --name "$0" -- "$@"`

eval set --"$PARSED"

while true; do
	case "$1" in
		-h|--help) echo "VALID FLAGS"
			echo "--delete-originals		: After an image is successfully converted, the original is deleted."
			echo "-i | --input 	[directory_path]: Manually specify input directory to convert. If not given, uses the same directory this script resides in."
			echo "-o | --output 	[directory_path]: Manually specify output directory for files"
			echo "-s | --strip			: Strips metadata from an image, if there is any."
			echo "-v | --overwrite		: Overwrites images instead of skipping them"
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
function convert_png() {
	# Arguments: File path, Output directory, Strip data, Overwrite, Delete Original

	# Remove the file path and file extension
	file_name="${1%.*}"
	file_name="${file_name##*/}"
	
	# Check if the converted video already exists
	target_path=""$2"/$file_name.webp"
	if [ "$4" = "n" ]; then
		ls "$target_path" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "Converted Image \"$file_name.webp\" already exists! Skipping (Use -v to overwrite)"
			return 1;
		fi
	fi
	
	echo "Converting \"$1\" to WebP"

	strip_string=""
	if [ "$3" = "y" ]; then
		strip_string="-strip"
	fi

	magick convert "$1" -alpha on $strip_string -define webp:lossless=true "$target_path"
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
	if [[ "$5" = "y" ]]; then
		rm "$1"
	fi

	return 0
}
export -f convert_png

# Search for any PNGs
find "$input_dir" -regex '.*.\([Pp][Nn][Gg]\)$' -exec bash -c "convert_png \"{}\" \"$output_dir\" $strip_metadata $overwrite_files $delete_originals" \;

