#!/bin/bash

# basicmeta - A basic metadata utility for sanity checking original camera files (frame rate, resolution and encoded date).
readonly BASICMETA_VERSION="1.1"

# Copyright (c) 2026 Luis Gómez Gutiérrez
# Licensed under the MIT License. See the LICENSE file in the project root for full license information.

function show_help() {
	echo "basicmeta v$BASICMETA_VERSION. A basic metadata utility for sanity checking original camera files"
	echo
	echo "Usage: basicmeta [options] <path>"
	echo
	echo "Options:"
	echo "  -f : Force analysis of non-camera video containers (MKV, AVI, M4V, MTS, FLV, WebM)"
	echo "  -h : Show this help message"
	echo "  --version  : Print version"
	exit 0
}

function get_abs_path() {
    local user_path="${1:-.}"
    if [[ -d "$user_path" ]]; then
        (cd "$user_path" && pwd)
    elif [[ -f "$user_path" ]]; then
        echo "$(cd "$(dirname "$user_path")" && pwd)/$(basename "$user_path")"
    else
        echo "$user_path"
    fi
}

function get_metadata() {
	local f="$1"
	local force="$2"
	local ext="${f##*.}"
	ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

	# Define colors only if outputting to a terminal (TTY)
	local dim="" red="" reset="" error_text="Unknown"
	if [[ -t 1 ]]; then
		dim="\033[38;5;246m"
		red="\033[0;31m"
		reset="\033[0m"
	fi
	local error_msg="$error_text"
	
	case "$ext" in
		mxf|mp4|mov)
			local res=$(mediainfo --Inform="Video;%Width% x %Height%" "$f")
			local full_meta=$(mediainfo --Inform="General;%FrameRate% fps -- REPLACE_RES -- %Encoded_Date% -- (%FileNameExtension%)" "$f")
			full_meta="${full_meta//.000 / }" 
			full_meta=$(echo "$full_meta" | sed 's/\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)[^-]*--/\1 --/') 

			# Prepare presentation variables
			local colored_unknown="${red}${error_text}${reset}"
			local colored_date_error="${red}Unknown date${reset}"
			
			# Handle variables
			[[ "$full_meta" =~ ^([[:space:]]|fps) ]] && full_meta="${colored_unknown} ${full_meta#* }"
			local final_res="${res:-$colored_unknown}"
			full_meta="${full_meta/REPLACE_RES/$final_res}"
			[[ "$full_meta" == *" --  -- "* ]] && full_meta="${full_meta/ --  -- / -- ${colored_date_error} -- }"
			
			local meta_part="${full_meta% -- (*}"
			local fname=" (${full_meta##*-- (}"

			printf "%b %b%s%b\n" "$meta_part" "$dim" "$fname" "$reset"
			;;
		r3d)
			local fps="" date="" w="" h="" name=""
			while IFS=': ' read -r key val; do
				case "$key" in
					FrameRate) fps="${val%.000}" ;;
					DateTimeOriginal) date=$(echo "$val" | sed -e 's/:/-/2' -e 's/:/-/1' | cut -c 1-10) ;;
					ImageWidth) w="$val" ;;
					ImageHeight) h="$val" ;;
					Filename|FileName) name="$val" ;;
				esac
			done < <(exiftool -s -s -FrameRate -DateTimeOriginal -ImageWidth -ImageHeight -Filename "$f")
			
			: "${fps:=$error_msg}"
			: "${w:=$error_msg}"
			: "${h:=$error_msg}"
			
			printf "%s fps -- %s x %s -- %s %b(%s)%b\n" "$fps" "$w" "$h" "$date" "$dim" "$name" "$reset"
			;;
		wav)
			local fps="" date="" name=""
			local error_fps="Unknown"
			local error_date="Unknown date"

			while IFS=': ' read -r key val; do
				case "$key" in
					BwfxmlSpeedTimecodeRate|iXML:SampleRate|Speed|VideoFrameRate)
						if [[ -z "$fps" ]]; then
							fps=$(printf "%.3f" "$val" 2>/dev/null || echo "$val")
							fps="${fps%.000}" 
						fi
						;;
					DateTimeOriginal|DateCreated|OriginatorReference|BwfxmlBextBwfOriginationDate)
						# Capture date, but ignore the "zero" date
						if [[ -z "$date" && "$val" =~ [1-9] ]]; then
							date=$(echo "$val" | sed -e 's/:/-/2' -e 's/:/-/1' | cut -c 1-10)
						fi
						;;
					Filename|FileName)
						name="$val"
						;;
				esac
			done < <(exiftool -s -s -BwfxmlSpeedTimecodeRate -iXML:SampleRate -Speed -VideoFrameRate -DateTimeOriginal -DateCreated -BwfxmlBextBwfOriginationDate -Filename "$f")
			
			# Handle Frame Rate and Date display
			local display_fps="${fps:-$error_fps}"
			[[ "$display_fps" == "$error_fps" && -n "$red" ]] && display_fps="${red}${display_fps}${reset}"
			local display_date="${date:-$error_date}"
			[[ "$display_date" == "$error_date" && -n "$red" ]] && display_date="${red}${display_date}${reset}"

			printf "%b fps -- Audio -- %b %b(%s)%b\n" "$display_fps" "$display_date" "$dim" "$name" "$reset"
			;;
		mkv|avi|m4v|mts|flv|webm)
			local res=$(mediainfo --Inform="Video;%Width% x %Height%" "$f")
			local full_meta=$(mediainfo --Inform="General;%FrameRate% fps -- REPLACE_RES -- %Encoded_Date% -- (%FileNameExtension%)" "$f")
			full_meta="${full_meta//.000 / }" 
			full_meta=$(echo "$full_meta" | sed 's/\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)[^-]*--/\1 --/') 

			# Prepare presentation variables
			local colored_unknown="${red}${error_text}${reset}"
			local colored_date_error="${red}Unknown date${reset}"
			
			# Handle variables
			[[ "$full_meta" =~ ^([[:space:]]|fps) ]] && full_meta="${colored_unknown} ${full_meta#* }"
			local final_res="${res:-$colored_unknown}"
			full_meta="${full_meta/REPLACE_RES/$final_res}"
			[[ "$full_meta" == *" --  -- "* ]] && full_meta="${full_meta/ --  -- / -- ${colored_date_error} -- }"
			
			local meta_part="${full_meta% -- (*}"
			local fname=" (${full_meta##*-- (}"

			printf "%b %b%s%b\n" "$meta_part" "$dim" "$fname" "$reset"
			;;
	esac
}

# Long-format flags
[[ "$1" == "--version" ]] && { echo "$BASICMETA_VERSION"; exit 0; }
[[ "$1" == "--help" ]] && show_help

# Short-format flags
bm_force=false
while getopts "fh" option
do
	case $option in
		f) bm_force=true ;;
		h) show_help ;;
		*) show_help ;;
	esac

done
shift "$((OPTIND-1))"

# Resolve source (Default to current directory)
bm_src=$(get_abs_path "${1:-$(pwd)}")


# --- Execution ---

if [[ -f "$bm_src" ]]; then
	get_metadata "$bm_src" "$bm_force"
elif [[ -d "$bm_src" ]]; then
	#Consider filter hidden directories with: find "$bm_src" -mindepth 1 -type f ! -path '*/.*' -print0 | sort -z | while IFS= read -r -d '' file; do
	find "$bm_src" -mindepth 1 -type f -print0 | sort -z | while IFS= read -r -d '' file; do
		get_metadata "$file" "$bm_force"
	done
else
	echo "Error: '$bm_src' is not a valid file or directory." >&2
	exit 1
fi