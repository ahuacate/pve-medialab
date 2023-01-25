#!/usr/bin/env bash

# Movies
if [ -d /mnt/video/movies ] && [ ! -f /mnt/video/movies/rsync_control_list_global-movies.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/video/movies/rsync_control_list_global-movies.txt
fi

# Series
if [ -d /mnt/video/series ] && [ ! -f /mnt/video/series/rsync_control_list_global-series.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/video/series/rsync_control_list_global-series.txt
fi

# Pron
if [ -d /mnt/video/pron ] && [ ! -f /mnt/video/pron/rsync_control_list_global-pron.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/video/pron/rsync_control_list_global-pron.txt
fi

# Homevideo
if [ -d /mnt/video/homevideo ] && [ ! -f /mnt/video/homevideo/rsync_control_list_global-homevideo.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/video/homevideo/rsync_control_list_global-homevideo.txt
fi

# Musicvideo
if [ -d /mnt/video/musicvideo ] && [ ! -f /mnt/video/musicvideo/rsync_control_list_global-musicvideo.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/video/musicvideo/rsync_control_list_global-musicvideo.txt
fi

# Documentary
if [ -d /mnt/video/documentary ] && [ ! -f /mnt/video/documentary/rsync_control_list_global-documentary.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/video/documentary/rsync_control_list_global-documentary.txt
fi

# Music
if [ -d /mnt/music ] && [ ! -f /mnt/music/rsync_control_list_global-music.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\nTo whitelist your whole music collection use the following: < w|* >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/music/rsync_control_list_global-music.txt
fi

# Photo
if [ -d /mnt/photo ] && [ ! -f /mnt/photo/rsync_control_list_global-photo.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/photo/rsync_control_list_global-photo.txt
fi
#-----------------------------------------------------------------------------------