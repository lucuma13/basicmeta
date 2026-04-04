#!/bin/bash

# basicmeta - A basic metadata utility for sanity checking original camera files (frame rate, resolution and encoded date).
readonly BASICMETA_VERSION="1.0"

# Copyright (c) 2026 Luis Gómez Gutiérrez
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

function basicmeta_show_help() {
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
		local dir
		dir=$(dirname "$user_path")
		if [[ -d "$dir" ]]; then
			echo "$(cd "$dir" && pwd)/$(basename "$user_path")"
		else
			echo "$user_path"
		fi
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
		error_msg="${red}${error_text}${reset}"
	else
		error_msg="${error_text}"
	fi
	
	case "$ext" in
		mxf|mp4|mov)
			local res=$(mediainfo --Inform="Video;%Width% x %Height%" "$f")
			local full_meta=$(mediainfo --Inform="General;%FrameRate% fps -- REPLACE_RES -- %Encoded_Date% " "$f")
			local fname=$(mediainfo --Inform="General;(%FileNameExtension%)" "$f")
			
			full_meta="${full_meta//.000 / }"
			# Error message if fps is missing (starts with a space or the line starting directly with "fps")
			[[ "$full_meta" =~ ^([[:space:]]|fps) ]] && full_meta="${error_msg} ${full_meta#* }"
			
			local output="${full_meta/REPLACE_RES/${res:-$error_msg}}"
			printf "%s%b%s%b\n" "$output" "$dim" "$fname" "$reset"
			;;
		r3d)
			local fps="" date="" w="" h="" name=""
			while IFS=': ' read -r key val; do
				case "$key" in
					FrameRate) fps="${val%.000}" ;;
					DateTimeOriginal) date=$(echo "$val" | sed -e 's/:/-/2' -e 's/:/-/1') ;;
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
			while IFS=': ' read -r key val; do
				case "$key" in
					BwfxmlSpeedTimecodeRate) fps="${val%.000}" ;;
					DateTimeOriginal) date=$(echo "$val" | sed -e 's/:/-/2' -e 's/:/-/1') ;;
					Filename|FileName) name="$val" ;;
				esac
			done < <(exiftool -s -s -BwfxmlSpeedTimecodeRate -DateTimeOriginal -Filename "$f")
			
			: "${fps:=$error_msg}"
			printf "%s fps -- %s %b(%s)%b\n" "$fps" "$date" "$dim" "$name" "$reset"
			;;
		mkv|avi|m4v|mts|flv|webm)
			if [[ "$force" == "true" ]]; then
				local res=$(mediainfo --Inform="Video;%Width% x %Height%" "$f")
				local full_meta=$(mediainfo --Inform="General;%FrameRate% fps -- REPLACE_RES -- %Encoded_Date% " "$f")
				local fname=$(mediainfo --Inform="General;(%FileNameExtension%)" "$f")
				full_meta="${full_meta//.000 / }"
				local output="${full_meta/REPLACE_RES/${res:-$error_msg}}"
				printf "%s%b%s%b\n" "$output" "$dim" "$fname" "$reset"
			else
				echo "Non-camera video container found: $ext. Use -f to force analysis."
			fi
			;;
	esac
}

# Long-format flags
[[ "$1" == "--version" ]] && { echo "$BASICMETA_VERSION"; exit 0; }
[[ "$1" == "--help" ]] && basicmeta_show_help

# Short-format flags
bm_force=false
while getopts "fh" option
do
	case $option in
		f) bm_force=true ;;
		h) basicmeta_show_help ;;
		*) basicmeta_show_help ;;
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