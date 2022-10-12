#!/bin/bash

# FFMPEG is needed to run this script

# You can specify the output directory here or pass it in as a command argument (Type --help)
output_dir=''
input_dir='.'
overwrite_files='n'

# Parse flags

SHORT_ARGS="hi:o:v"
LONG_ARGS=help,input:,output:,overwrite

PARSED=`getopt --options $SHORT_ARGS --longoptions $LONG_ARGS --name "$0" -- "$@"`

eval set --"$PARSED"

while true; do
	case "$1" in
		-h|--help) echo "VALID FLAGS"
			echo "-i | --input 	[directory_path]: Manually specify input directory to convert. If not given, uses the same directory this script resides in."
			echo "-v | --overwrite		: Makes ffmpeg overwrite files instead of skipping them"
			echo "-o | --output 	[directory_path]: Manually specify output directory for files"
			exit 0
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
fi

if [ -d "$output_dir" ]; then
	curr_file_idx=1;
	total_files=$(find "$input_dir" -name *.gif | wc -l);
	if [ $total_files -eq 0 ]; then
		echo "No GIFs to convert";
		exit 0;
	fi
	for file in "$input_dir"/*.gif; do
		file_name=$(basename "$file" .gif);
		target_path="$output_dir/$file_name.mp4";

		# ffmpeg's no overwrite flag returns an error code and screws up the error checker.
		if [ "$overwrite_files" = "n" ]; then
			ls "$target_path" >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "Converted GIF \"$file_name.mp4\" already exists! Skipping (Use -v to overwrite)"
				let curr_file_idx=$curr_file_idx+1;
				continue;
			fi
		fi

		echo "Converting \""$file"\" ($curr_file_idx/$total_files)";
		ffmpeg -i "$file" -y -hide_banner -loglevel warning -stats -movflags faststart -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$target_path";
		exit_code=$?;
		if [ $exit_code -eq 255 ]; then
			echo "Terminating program."
			break;
		fi
		if [ ! $exit_code -eq 0 ]; then
			echo "An error has occurred. Please refer to any above output." >&2;
			exit 1;
		fi
		let curr_file_idx=$curr_file_idx+1;
	done;
else
	echo "Failed to create output directory. Insufficient permissions?" >&2;
fi
