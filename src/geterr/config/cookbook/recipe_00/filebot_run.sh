#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     filebot_run.sh
# Description:  Script to rename and sort media downloaded media using FileBot.
#               Executed by parent 'recipe.sh'
#               This script must run as user 'media'
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# All variables are set in 'variables_default.yml' using function 'parse_yml'.

#---- Static Variables -------------------------------------------------------------

#---- FlexGet rename arg templates
# The renaming convention is set by '$mediaserver_type' in 'variables_default.yml'.
# Your options are 'plex.id', 'emby.id' or 'jellyfin.id'. Do not edit here.

# Rename tmpl - Series
series_fmt='{ any{ genre ==~ /Documentary|News|History|Food|Reality|Travel|Sport|War|Biography|Film Noir|Reality-TV|DIY|Espionage|Legal|Nature|Talk|War & Politics/ ? \"$path_documentary_series_dst/\" : { fn =~ /(\[.*(?i:documentary|doco|news|history).*\])/ ? \"$path_documentary_series_dst/\" : \"$path_series_dst/\" } }{ \"$path_documentary_series_dst/\" }}{ ~$mediaserver_type }{\" \"}{ allOf{ vf }{ vc }{ ac }{ hdr } }{ \".\"+lang.ISO2 }'

# Rename tmpl - Movie
movie_fmt='{ any{ genre ==~ /Documentary|News|History|Food|Reality|Travel|Sport|War|Biography|Film Noir|Reality-TV|DIY|Espionage|Legal|Nature|Talk|War & Politics/ ? \"$path_documentary_movies_dst/\" : \"$path_movies_dst/\" }{ \"$path_documentary_movies_dst/\" }}{ ~$mediaserver_type }{\" \"}{ allOf{ vf }{ vc }{ ac }{ hdr } }{ \".\"+lang.ISO2 }'

# Rename tmpl - Anime
anime_fmt="anime/{primaryTitle}/{primaryTitle} - {sxe} - {t.replaceAll(/[\!?.]+$/).replaceAll(/[\`´‘’ʻ]/, /'/).replacePart(', Part \$1')}"

# Rename tmpl - Music
music_fmt='{ ~plex.id }'


#---- Other Variables --------------------------------------------------------------

# FileBot action
# Options are: move, copy, test
# Default is 'copy'
action_arg="copy"

# FileBot conflict
# Options are: skip, auto, fail
# Default is 'skip'. Stops duplication
conflict_arg="skip"

# Can be customized using 'dl_type' etc.
# Default is: '/mnt/downloads/unsorted'. Set in' variables.default.yml'.
# unsorted_path="$storage_downloads/$path_unsorted"

# Log dir
log_dir="$HOME/.filebot"

#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Function to validate input file format
function validate_file_format() {
  if [[ ! $1 =~ ^([\=\!])\;([0-9]*|)\;([0-9]*|)\;(tt[0-9]+|[0-9]+|)\;([0-9]*|)\;([0-9]*|)\;([^;]+(;[^;]+)*)$ ]]
  then
    return 1
  fi
}

# Function to get the label of a file based on its path and name
get_label() {
  local file="$1"

  # First, check for a label in square brackets
  if [[ $file =~ \[([^]]+)\] ]]; then
      local label="${BASH_REMATCH[1]}"
      if [[ $label =~ ^series ]]; then
          echo "series"
      elif [[ $label =~ ^movie ]]; then
          echo "movie"
      elif [[ $label =~ ^music ]]; then
          echo "music"
      elif [[ $label =~ ^anime ]]; then
          echo "anime"
      elif [[ $label =~ ^unsorted ]]; then
          echo "unsorted"
      fi
  else
      # Check for series in the path
      if [[ $file =~ /series/ ]]; then
          echo "series"
      elif [[ $file =~ /movie/ ]]; then
          echo "movie"
      elif [[ $file =~ /music/ ]]; then
          echo "music"
      elif [[ $file =~ /anime/ ]]; then
          echo "anime"
      else
          echo "unsorted"
      fi
  fi
}

# Set FileBot exclude filter (function)
function set_filter_exclude_arg() {
	# Sets --filter arg (csv exclude filename)
	filter_exclude_filename=""
	for item in "${filter_exclude_LIST[@]}"
	do
		if [[ "${item%%;*}" == "$db_arg" ]]
		then
			filter_exclude_filename="${item#*;}"
			break
		fi
	done
}

# Set FileBot '--output' & '--format' args (function)
function set_output_format_arg() {
	for item in "${filter_db_basedir_LIST[@]}"
	do
		if [[ "${item%%;*}" == "$db_arg" ]]
		then
			# Set '--output' arg
			IFS=';' read -ra items <<< "$item"
			output_base_dir="${items[1]}"
			# Set '--format' arg
			output_file_fmt="${items[2]}"
			break
		fi
	done
}

# FileBot CMD
function filebot_rename() {
	# This func runs the FileBot rename cmd
	# Optional args are '--filter exclude' and '--q $id'
  local cmd="filebot -rename \"$src_file\" --action \"$action_arg\" \
             --output \"$output_base_dir\" \
             --conflict \"$conflict_arg\" \
             --db \"$db_arg\" \
             --apply artwork nfo metadata srt \
             --format \"$output_file_fmt\" -no-xattr \
             --log-file \"$log_dir/filebot_log.txt\" \
             -non-strict"
	# Append $id
  if [ -n "$id" ]
	then
    cmd+=" --q \"$id\""
  fi
	# Append filter
	if [ -n "$filter_exclude_list" ]
	then
    cmd+=" --filter '!(id in csv(\"$filter_exclude_list\"))'"
  fi
	# Run FileBot
  eval "$cmd"
}

# Make completed log entry
function make_completed_log {
  # Add the current date and the source file name to the log file
  echo "$(date);$src_file" >> "$log_dir/completed.txt"

  # Get the size of the log file in bytes
  size=$(wc -c < "$log_dir/completed.txt")

  # If the size exceeds 5MB, prune the oldest entries
  if (( size > 5000000 )); then
    # Determine the number of lines to remove
    lines_to_remove=$(( (size - 5000000) / ($(wc -c < "$log_dir/completed.txt") / $(wc -l < "$log_dir/completed.txt")) ))

    # Remove the oldest entries from the log file
    sed -i "1,${lines_to_remove}d" "$log_dir/completed.txt"
  fi
}


#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Create log dir
mkdir -p "$log_dir"

# Required log file lists
filename_LIST=( "$log_dir/filebot_log.txt" "$log_dir/completed.txt" )
for filename in "${filename_LIST[@]}"
do
  if [ ! -f "$filename" ]
  then
    # Create the missing file
    touch "$filename"
  fi
done

#---- Create ID lists (include & exclude)

# Initialize the array
filter_lookup_LIST=()

# Read from 'filter_lookup_master_list.txt' and add each line a array
while read -r line
do
  if ! validate_file_format "$line"
  then
    continue
  fi
  filter_lookup_LIST+=("$line")
done < $DIR/filter_lookup_master_list.txt
# Read from your 'my_filter_lookup_list.txt', validate each line, and add to array
if [[ -f my_filter_lookup_list.txt ]]
then
  while read -r line
  do
    if ! validate_file_format "$line"
    then
      continue
    fi
    filter_lookup_LIST+=("$line")
  done < $DIR/my_filter_lookup_list.txt
fi

# Initialize db 'include' and 'exclude' arrays
filter_include_tmdb_LIST=()
filter_exclude_tmdb_LIST=()
filter_include_tvdb_LIST=()
filter_exclude_tvdb_LIST=()
filter_include_imdb_LIST=()
filter_exclude_imdb_LIST=()
filter_include_tvmaze_LIST=()
filter_exclude_tvmaze_LIST=()

# Initialize associative array for seen names
unset seen_names
declare -A seen_names

# Read lines from '"${filter_lookup_LIST[@]}"' and populate each db array
while IFS=';' read -r inc_exc tmdbid tvdbid imdbid tvmazeid anidbid names
do
  # Split names into an array
  IFS=';' read -ra name_arr <<< "$names"
  # Add entries to respective arrays based on inc_exc flag and ID type
  for name in "${name_arr[@]}"
  do
    if [[ ! ${seen_names["$name"]} ]]
    then
      seen_names["$name"]=1
      if [[ "$inc_exc" == "=" ]]; then
        if [[ -n "$tmdbid" ]]; then
          filter_include_tmdb_LIST+=( "$tmdbid;$name" )
        fi
        if [[ -n "$tvdbid" ]]; then
          filter_include_tvdb_LIST+=( "$tvdbid;$name" )
        fi
        if [[ -n "$imdbid" ]]; then
          filter_include_imdb_LIST+=( "$imdbid;$name" )
        fi
        if [[ -n "$tvmazeid" ]]; then
          filter_include_tvmaze_LIST+=( "$tvmazeid;$name" )
        fi
      elif [[ "$inc_exc" == "!" ]]; then
        if [[ -n "$tmdbid" ]]; then
          filter_exclude_tmdb_LIST+=( "$tmdbid;$name" )
        fi
        if [[ -n "$tvdbid" ]]; then
          filter_exclude_tvdb_LIST+=( "$tvdbid;$name" )
        fi
        if [[ -n "$imdbid" ]]; then
          filter_exclude_imdb_LIST+=( "$imdbid;$name" )
        fi
        if [[ -n "$tvmazeid" ]]; then
          filter_exclude_tvmaze_LIST+=( "$tvmazeid;$name" )
        fi
      fi
    fi
  done
done < <( printf '%s\n' "${filter_lookup_LIST[@]}" )


# Create '--filter' exclude csv files for each db
# Define the exclude array names
array_names=("tmdb" "tvdb" "imdb" "tvmaze")
# Loop through the array names
for name in "${array_names[@]}"
do
  # Define the array variable name
  array_variable="filter_exclude_${name}_LIST"

  # Define the output file name
  output_file="filter_exclude_${name}_list.tsv"

  # Write the array to the output file
  eval "printf '%s\n' \"\${$array_variable[@]}\"" > $DIR/$output_file
done


#---- Create input list array

# Initialize array for 'completed_log_LIST'
completed_log_LIST=()

# Create array list of completed files (from log file: '$log_dir/completed.txt')
while IFS=';' read -r date src_file
do
  # Check if the line starts with "#" and skip it
  if [[ $src_file == \#* ]]
  then
    continue
  fi
  # Otherwise, add the second field to the completed_log_LIST array
  completed_log_LIST+=("$src_file")
done < "$log_dir/completed.txt"

# Initialize array for 'src_dst_base_path_LIST'
src_dst_base_path_LIST=()

# Create an array of matched src and dst path pairs & dl type
# i.e src path;dst path;usenet|torrent
for var_src in $(compgen -v | grep "^path_.*src$")
do
  var_dst="${var_src%_src}_dst"
	src_dst_base_path_LIST+=("$storage_downloads_torrent/${!var_src};${!var_dst};torrent")
	src_dst_base_path_LIST+=("$storage_downloads_usenet/${!var_src};${!var_dst};usenet")
done

# Create 'input_file_LIST' array
# Find all files in src directories that match the '$filter_all_ext_regex', apply
# age limit prune and assign file dst path.
# Output:
#     - video input file path (src_path)
#     - video destination storage sub-path (dst_path)
#     - download file source type: torrent or usenet (dl_type)
#     - FileBot processing setting (type)

# Initialize associative array for 'input_file_LIST'
input_file_LIST=()
# Create regex of all allowed file extensions (video & music file extensions etc)
filter_all_ext_regex="$(awk '/^[^#]/ && NF {printf "\\.%s$|", $1}' $DIR/filter_audio_format.txt $DIR/filter_video_format.txt | sed 's/|$//')"
while IFS=';' read -r src_path dst_path dl_type
do
  # Check if 'src_path' exists
  if [ -d "$src_path" ]
  then
    while IFS= read -r -d '' file
    do
      # Check completed log for $file
      # Loop over the elements of the array
      for element in "${completed_log_LIST[@]}"
      do
        # Check if the current element is equal to the filename
        if [ "$element" = "$file" ]
        then
          # Skip file
          continue 2
        fi
      done

      # Get file age
      file_age_hours=$(( ( $(date +%s) - $(stat -c %Y "$file") ) / 3600 ))

			# Create input list based if src meets age criteria
      if [[ $file_age_hours -lt $filebot_age_src ]]
      then
				# Extract the movie/series name from the filename
				name=$(basename "$file" | sed 's/\./ /g;s/\s*-\s*.*/ /;s/\s*$//')

				# Extract SeriesID/MovieID if exists
				id=$(echo "$file" | sed -n 's/.*{\([^}]*\)\}.*/\1/p')

				# Get the label of the file
				label=$(get_label "$file")

        # Create list
        input_file_LIST+=("$file;$dst_path;$name;$id;$label;$unsorted_path;$dl_type")
      fi
    done < <( find "$src_path" -type f -regextype posix-extended -regex ".*($filter_all_ext_regex)" -print0 )
  fi
done < <( printf '%s\n' "${src_dst_base_path_LIST[@]}" )


#---- Create FileBot arguments

# Check 'input_file_LIST' cnt.
if [ "${#input_file_LIST[@]}" = 0 ]
then
	# Exit script (cnt = 0)
	return
fi

# Read from file 'input_file_LIST' array
while IFS=';' read -r src_file dst_path name id label unsorted_path dl_type
do
	# Lookup databases
	series_db_LIST=( "TheMovieDB::TV" "TheTVDB" "TVmaze" )
	movie_db_LIST=( "TheMovieDB" )
	music_db_LIST=( "AcoustID" "ID3" )
	anime_db_LIST=( "AniDB" )
	unsorted_db_LIST=( "TheMovieDB::TV" "TheTVDB" "TVmaze" "TheMovieDB" "AcoustID" "ID3" )

	# Set match list
	# Initialize arrays
	match_db_LIST=()
	if [ "$label" = series ]
	then
		match_db_LIST=("${series_db_LIST[@]}")
	elif [ "$label" = movie ]
	then
		match_db_LIST=("${movie_db_LIST[@]}")
	elif [ "$label" = music ]
	then
		match_db_LIST=("${music_db_LIST[@]}")
	elif [ "$label" = anime ]
	then
		match_db_LIST=("${anime_db_LIST[@]}")
	elif [ "$label" = unsorted ]
	then
		match_db_LIST=("${unsorted_db_LIST[@]}")
	fi

	#### Check for ID
	# Initialize array
	id_lookup_LIST=()

	# Extract {id value} from 'input_file_LIST' line
	if [ -n "$id" ]
	then
		id_db=$(echo $id | awk -F'-' '{ print $1 }')
		id_num=$(echo $id | awk -F'-' '{ print $2 }')
    case $id_db in
      tmdb_tv)
        db_arg='TheMovieDB::TV'
        ;;
      tmdb)
        db_arg='TheMovieDB'
        ;;
      tvdb)
        db_arg='TheTVDB'
        ;;
      tvmaze)
        db_arg='TVmaze'
        ;;
      anidb)
        db_arg='AniDB'
        ;;
			imdb)
        db_arg='TheMovieDB'
        ;;
			acoustid)
        db_arg='AcoustID'
        ;;
			music)
        db_arg='AcoustID'
        ;;
			id3)
        db_arg='ID3'
        ;;
      *)
        # Skip unknown database types
        continue
        ;;
    esac

		# IMDB override (i.e tt1234567) for FileBot
		if [[ "$id_num" =~ ^tt[0-9]+ ]]
		then
			db_arg='TheMovieDB'
		fi

		# Create id entry
		id_lookup_LIST+=("$id_num;$db_arg")
	fi

	# Look up $name in 'filter_include_LIST' and add to 'id_lookup_LIST' on match
	# Initialize array
	filter_exclude_LIST=()
	filter_include_LIST=()
	filter_db_basedir_LIST=()

	# Match $db to associated filter, associated base dir
  for db in "${match_db_LIST[@]}"
  do
    case $db in
      TheMovieDB::TV)
        db_arg='TheMovieDB::TV'
        filter_include_LIST=("${filter_include_tmdb_LIST[@]}")
				# Set $filter_exclude_list csv for $db_arg
				filter_exclude_LIST+=( "$db_arg;$DIR/filter_exclude_tmdb_list.csv" )
				# Set base dir and type
				filter_db_basedir_LIST+=( "$db_arg;$storage_video;$series_fmt" )
        ;;
      TheTVDB)
        db_arg='TheTVDB'
        filter_include_LIST=("${filter_include_tvdb_LIST[@]}")
				# Set $filter_exclude_list csv for $db_arg
				filter_exclude_LIST+=( "$db_arg;$DIR/filter_exclude_tvdb_list.csv" )
				# Set base dir and type
				filter_db_basedir_LIST+=( "$db_arg;$storage_video;$series_fmt" )
        ;;
      TVmaze)
        db_arg='TVmaze'
        filter_include_LIST=("${filter_include_tvmaze_LIST[@]}")
				# Set $filter_exclude_list csv for $db_arg
				filter_exclude_LIST+=( "$db_arg;$DIR/filter_exclude_tvmaze_list.csv" )
				# Set base dir and type
				filter_db_basedir_LIST+=( "$db_arg;$storage_video;$series_fmt" )
        ;;
      TheMovieDB)
        db_arg='TheMovieDB'
        filter_include_LIST=("${filter_include_tmdb_LIST[@]}")
				# Set $filter_exclude_list csv for $db_arg
				filter_exclude_LIST+=( "$db_arg;$DIR/filter_exclude_tmdb_list.csv" )
				# Set basedir(s) and type
				filter_db_basedir_LIST+=( "$db_arg;$storage_video;$movie_fmt" )
        ;;
      AniDB)
        db_arg='AniDB'
        filter_include_LIST=("${filter_include_anidb_LIST[@]}")
				# Set $filter_exclude_list csv for $db_arg
				filter_exclude_LIST+=( "$db_arg;" )
				# Set base dir and type
				filter_db_basedir_LIST+=( "$db_arg;$storage_video;$anime_fmt" )
        ;;
      AcoustDB)
        db_arg='AcoustID'
				# Set $filter_exclude_list csv for $db_arg
				filter_exclude_LIST+=( "$db_arg;" )
				# Set base dir and type
				filter_db_basedir_LIST+=( "$db_arg;$storage_music;$music_fmt" )
        ;;
      ID3)
        db_arg='ID3'
				# Set $filter_exclude_list csv for $db_arg
				filter_exclude_LIST+=( "$db_arg;" )
				# Set base dir and type
				filter_db_basedir_LIST+=( "$db_arg;$storage_music;$music_fmt" )
        ;;
      *)
        # Skip unknown database types
        break
        ;;
    esac

    # Look up $name in 'filter_include_LIST' and get $id on match
    # Convert $name to lowercase and remove all periods, spaces, and special characters
    name_clean=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr -d '[:punct:][:space:]'| iconv -f utf8 -t ascii//TRANSLIT)
    # Look up $name in 'filter_include_LIST' and get $id on match
    for filter_entry in "${filter_include_LIST[@]}"
    do
      # Convert $filter_entry field 2 to lowercase and remove all periods and special characters
      filter_entry_clean=$(echo "$filter_entry" | cut -d';' -f2 | tr '[:upper:]' '[:lower:]' | tr -d '[:punct:][:space:]' | iconv -f utf8 -t ascii//TRANSLIT)

      # Check for a case-insensitive partial match between $filter_entry_clean and $name_clean
      if [[ "$name_clean" =~ ^(the)?${filter_entry_clean} ]]
      then
        # Extract ID No.
        id_num=$(echo "$filter_entry" | cut -d';' -f1)
        # Add id, db & filter exclude entry to 'id_lookup_LIST'
        id_lookup_LIST+=("$id_num;$db_arg")
      fi
    done
	done


	#---- Run FileBot Rename

	# Run FileBot cmd (with --q)
	if [ ! "${#id_lookup_LIST[@]}" = 0 ]
	then
		for id_lookup in "${id_lookup_LIST[@]}"
		do
			# Set $id and $db_arg
			IFS=';' read -r id db_arg <<< "$id_lookup"
			# Func - Set exclude filter arg
			set_filter_exclude_arg
			# Func - Set '--output' & '--format' args
			set_output_format_arg
			# Func - Run FileBot rename
			filebot_rename

			# On FileBot success and/or existing file proceed to next file
      # Use '0' and '1'. On '3' will try another db to match is what we want.
      # int SUCCESS = 0
      # int ERROR = 1 (also includes existing files error)
      # int BAD_LICENSE = 2
      # int FAILURE = 3
      # int DIE = 4
      # int NOOP = 100
      if [[ $? =~ 0|1 ]]
      then
        # Make completed log entry
        make_completed_log
        # Set to copy the file to $path_unsorted ('0' false, '1' true)
        unsorted=0
        # Proceed to next file
        continue 2
      fi
		done
	fi

	# Run FileBot cmd (without --q)
  for db_arg in "${match_db_LIST[@]}"
  do
		# Func - Set exclude filter arg
		set_filter_exclude_arg
		# Func - Set '--output' & '--format' args
		set_output_format_arg
		# Func - Run FileBot rename
		filebot_rename

    # On FileBot success and/or existing file proceed to next file
    # Use '0' and '1'. On '3' will try another db to match is what we want.
    # int SUCCESS = 0
    # int ERROR = 1 (also includes existing files error)
    # int BAD_LICENSE = 2
    # int FAILURE = 3
    # int DIE = 4
    # int NOOP = 100
  
    if [[ $? =~ 0|1 ]]
		then
      # Make completed log entry
      make_completed_log
      # Set to copy the file to $path_unsorted ('0' false, '1' true)
      unsorted=0
      # Proceed to next file
      continue 2
		fi
	done

	# Run FileBot cmd (last resort - without --q, try all unsorted dbs)
  for db_arg in "${unsorted_db_LIST[@]}"
  do
		# Func - Set exclude filter arg
		set_filter_exclude_arg
		# Func - Set '--output' & '--format' args
		set_output_format_arg
		# Func - Run FileBot rename
		filebot_rename

    # On FileBot success and/or existing file proceed to next file
    # Use '0' and '1'. On '3' will try another db to match is what we want.
    # int SUCCESS = 0
    # int ERROR = 1 (also includes existing files error)
    # int BAD_LICENSE = 2
    # int FAILURE = 3
    # int DIE = 4
    # int NOOP = 100
    if [[ $? =~ 0|1 ]]
		then
      # Make completed log entry
      make_completed_log
      # Set to copy the file to $path_unsorted ('0' false, '1' true)
      unsorted=0
      # Proceed to next file
      continue 2
    else
      # Set to copy the file to $path_unsorted ('0' false, '1' true)
      unsorted=1
		fi
	done

	# On FileBot failure copy the file to $path_unsorted
	if [ "$unsorted" = 1 ] && [ ! "$filebot_action" = test ]
	then
    # Copy all associated '$src_file' files to '$path_unsorted'
    src_file_name=$(basename "$src_file" | cut -f 1 -d '.')
    src_dir=$(dirname "$src_file")
    cp "$src_dir/$src_file_name"* "$storage_downloads/$path_unsorted" 2>/dev/null
    # Make completed log entry
    make_completed_log
	fi
done < <( printf '%s\n' "${input_file_LIST[@]}" )
#-----------------------------------------------------------------------------------