# Dupes - a very special usecase for a friend, in bash
Stores properties of (rarred) movies and series into a sqlite3 database.  
Then removes duplicates based on their properties, e.g. used codec, videobitrate, dynamic range formats, tags, etc.  
Can perform deduplication within the same amount of pixels (e.g. best of 720, best of 1080, best of 2160) or keep the best of all.  

Sample output with explanation: 
```
DEL: /movies/Unreal.Tournament.2021.2160p.WEB.H265-SURK (sdr|v:11550kb/s) | KEEP: /x265-2160p/Unreal.Tournament.2021.HDR.2160p.WEB.H265-BLUR (hdr|v:13622kb/s)  
```
HDR wins from SDR  
```
DEL: /web-dl/Cry.Me.A.River.2021.1080p.WEB.H264-NICE (web|h264|v:8056kb/s) | KEEP: /x264/Cry.Me.A.River.2021.1080p.BluRay.x264-BURN (bluray|x264|v:12855kb/s)  
```
A better source was found in a different directory (bluray vs web). Bitrate is higher. Codec isn't but in this configuration output is ordered by source, then codec, then ... More info below  
```
DEL: /tv-us/My.Blood.S01E07.1080p.WEB.H264-PULSATE (v:5018kb/s|no_tags) | KEEP: /tv-us/My.Blood.S01E07.PROPER.1080p.WEB.H264-COOKING (v:4870kb/s|proper)  
```
A proper version is found. Bitrate is lower, but these tags weigh higher  
```
DEL: /tv-us/1986.S01E01.1080p.WEB.H264-TOOQUICK (no_tags) | KEEP: /tv-us/1986.S01E01.REPACK.1080p.WEB.H264-TOOQUICK (repack)  
```
Seems like no other differences are found (e.g. bitrate, codec), it's just the tag REPACK that makes it the winner  
```
DEL: /tv-us/The.Whitch.S02E01.1080p.WEB.H264-TOOBAD (2021-12-17 09:11:40) | KEEP: /tv-us/The.Whitch.S02E01.1080p.WEB.H264-QUICK (2021-12-17 09:04:13)  
```
If nothing else is different (even up to videobitrate), the only difference that was found is the fact that -QUICK was created earlier on harddisk  


Another example when using the "best of all" mode, in case all sections are scanned for the same movie and only the best (2160p, UHD, HDR, H265) is kept:
```
DEL: /movies/Super.Movie.1080p.BluRay.x264-SHINYDISC (1080|bluray|sdr|x264|v:8966kb/s) | KEEP: /movies/Super.Movie.HDR.2160p.UHD.WEB.h265-UHDWEBZ (2160|uhd|hdr|h265|v:8056kb/s)
DEL: /movies/Super.Movie.1080p.WEB.H264-WEBGRP (1080|web|sdr|h264|v:7812kb/s) | KEEP: /movies/Super.Movie.HDR.2160p.UHD.WEB.h265-UHDWEBZ (2160|uhd|hdr|h265|v:8056kb/s)
DEL: /movies/Super.Movie.1080p.WEBRip.x264-WEBRIPZZ (1080|webrip|sdr|x264|v:6221kb/s) | KEEP: /movies/Super.Movie.HDR.2160p.UHD.WEB.h265-UHDWEBZ (2160|uhd|hdr|h265|v:8056kb/s)
DEL: /movies/Super.Movie.720p.WEB.H264-LOWQUALI (720|web|sdr|h264|v:4523kb/s) | KEEP: /movies/Super.Movie.HDR.2160p.UHD.WEB.h265-UHDWEBZ (2160|uhd|hdr|h265|v:8056kb/s)
```

Enjoy!


## Requirements
- (chrooted) folder structure like /site/movies/, /site/movie-1080/, /site/movie-2160/, /site/tv-720/, /site/tv-uk-720/, /site/tv-uk-1080/, called sections
- (chrooted) sqlite3
- (chrooted) mediainfo utility to extract media information from files, including rar support
- at this point i'm assuming you have a working glftpd installation in /jail/glftpd probably with pzs-ng installed too

Tested on: Ubuntu 20.04.3 LTS (focal) 

Also known to be working on: Debian 10 (buster)

# Installation (easy, without Mediainfo)
## Prerequisites
apt install git sqlite3 bc  
cp /bin/expr /bin/rev /bin/stat /bin/bc /jail/glftpd/bin/  

## sqlite3 to chroot:
- cp /bin/sqlite3 /jail/glftpd/bin/
- /jail/glftpd/libcopy.sh

test sqlite3:
- chroot /jail/glftpd /bin/sqlite3

exit with ".quit"

## Additional
Proceed to: Clone this project  
Edit the .sh files. Comment the following lines:
```
proc_get_mediainfo_for $i
VBR=$(proc_get_video_bitrate_for $i)
```
And add this line below that:
```
VBR=0
```

# Installation (with Mediainfo, slightly more complex and with more dependencies)
## Prerequisites
apt install libmediainfo-dev git build-essential sqlite3 bc  
cp /bin/expr /bin/rev /bin/stat /bin/bc /jail/glftpd/bin/  

## Mediainfo
Get the latest source code from the mediaarea.net website (https://mediaarea.net/en/MediaInfo/Download/Source)
- wget https://mediaarea.net/download/binary/mediainfo/21.09/MediaInfo_CLI_21.09_GNU_FromSource.tar.gz
- tar zxvf MediaInfo_CLI_21.09_GNU_FromSource.tar.gz
- cd MediaInfo_CLI_21.09_GNU_FromSource
- ./CLI_Compile.sh --enable-static --enable-staticlibs
- cd MediaInfo/Project/GNU/CLI && make install

(result = /usr/local/bin/mediainfo)

## Patched LibDVDRead
- wget http://lundman.net/ftp/dvdread/libdvdread-4.2.0.plus.tar.gz
- tar zxvf libdvdread-4.2.0.plus.tar.gz
- cd libdvdread-4.2.0.plus
- ./configure && make && make install

(result = /usr/local/lib/mediainfo****)

## Mediainfo with rar support
- wget http://www.lundman.net/ftp/mediainfo-rar/mediainfo-rar-1.4.0.tar.gz
- tar zxvf mediainfo-rar-1.4.0.tar.gz
- cd mediainfo-rar-1.4.0
- ./configure && make && make install

(result = /usr/local/bin/mediainfo-rar + unrar)

- ln -s /usr/local/lib/libdvdread.so.4 /lib/x86_64-linux-gnu/libdvdread.so.4
- cd /usr/local/bin/
- cp mediainfo mediainfo-rar unrar /jail/glftpd/bin/
- /jail/glftpd/libcopy.sh

make sure you don't see errors!!

## mediainfo(-rar) dependencies
- mkdir -p /jail/glftpd/usr/lib/x86_64-linux-gnu/
- cp -P /usr/lib/x86_64-linux-gnu/libmediainfo* /jail/glftpd/usr/lib/x86_64-linux-gnu/ 

(sorry about all the following dependencies. Please, can someone explain to me why these are needed?)
- cd /usr/lib/x86_64-linux-gnu/
- cp -P libzen.so* libcurl-gnutls.so* libmms.so* libtinyxml2.so* libnghttp2.so* libidn2.so* librtmp.so* libssh.so* libpsl.so* libnettle.so* libgnutls.so* libgssapi_krb5.so* libldap_r-2.4.so* liblber-2.4.so* libbrotlidec.so* /jail/glftpd/usr/lib/x86_64-linux-gnu/
- cp -P libhogweed.so* libp11-kit.so* libunistring.so* libtasn1.so* libgmp.so* libkrb5.so* libk5crypto.so* libcom_err.so* libkrb5support.so* libresolv.so* libsasl2.so* libgssapi.so* libbrotlicommon.so* /jail/glftpd/usr/lib/x86_64-linux-gnu/
- cp -P libasn1.so* libffi.so* libhcrypto.so* libheimbase.so* libheimntlm.so* libhx509.so* libkeyutils.so* libresolv* libroken.so* libsqlite3.so* libwind.so* /jail/glftpd/usr/lib/x86_64-linux-gnu/

## sqlite3 to chroot:
- cp /bin/sqlite3 /jail/glftpd/bin/
- /jail/glftpd/libcopy.sh

test sqlite3:
- chroot /jail/glftpd /bin/sqlite3

exit with ".quit"

# Clone this project
- mkdir -p /jail/glftpd/db/mediainfo && mkdir -p /jail/glftpd/db/tmp && cd /jail/glftpd/db
- git clone https://github.com/flowerboutique/dupes.git
- mv dupes/* . && rm -rf dupes
- edit conf files. Explanation is in the files.

## Set up the functions
Open moviedupes.sh. At the bottom, you see the functions beging called in the following order:
```
#proc_create_database
proc_remove_non_existent
proc_makelist
proc_insertintodatabase
proc_searchfordupes_with_pixels "060_2160" "FORCE"
#proc_searchfordupes_with_pixels "060_2160"
proc_searchfordupes_with_pixels "070_1080" "FORCE"
#proc_searchfordupes_with_pixels "070_1080"
#proc_searchfordupes_with_pixels "080_720" "FORCE"
#proc_searchfordupes_with_pixels "080_720"
#proc_searchfordupes "FORCE" "FORCE"
#proc_searchfordupes  # <- global, without the restriction of pixels. Best quality wins.
proc_delete_dead_symlink
```
Here's the explanation:
### proc_create_database 
Creates an empty sqlite3 database. Hence it is commented out. You should only uncomment it at the first run or when you want to create a totally clean situation.

### proc_remove_non_existent
Once the database is filled, the next time the script runs, it cleans out no (longer) existing directories.

### proc_makelist
Scans the sections from the .conf file and creates the temporary list.

### proc_insertintodatabase
Parses the temporary list, checks if all the directories are present in the database. If not, it appends with all relevant data.

### proc_searchfordupes_with_pixels
Here's where all the magic happens. First parameter is the code for the resolution. If the second parameter is FORCE then it will delete stuff.

### proc_searchfordupes
Same as the function _with_pixels, but this one will look for the best release in all the sections/resolutions. Use "FORCE" "FORCE" if you really want to delete directories, since it requires two parameters (lazy).

### proc_delete_dead_symlink
Turns out that cleaning dead symlinks is very usefull.

# Run
The bottom of the .sh files call the functions in a specific order. You can play around with it.

The initial run should probably have the following function calls:
```
proc_create_database
#proc_remove_non_existent  # <-- has no use during this first run, since there is no content yet
proc_makelist
proc_insertintodatabase
#proc_searchfordupes_with_pixels "060_2160" "FORCE"
#proc_searchfordupes_with_pixels "060_2160"
#proc_searchfordupes_with_pixels "070_1080" "FORCE"
#proc_searchfordupes_with_pixels "070_1080"
#proc_searchfordupes_with_pixels "080_720" "FORCE"
#proc_searchfordupes_with_pixels "080_720"
#proc_searchfordupes "FORCE" "FORCE"
#proc_searchfordupes
proc_delete_dead_symlink  # <-- why not
```
Next run:
```
#proc_create_database  # <-- if you enable this one, it will wipe the database
proc_remove_non_existent  # <-- nothing has been deleted yet, so probably will do nothing at a second run
proc_makelist
proc_insertintodatabase
#proc_searchfordupes_with_pixels "060_2160" "FORCE"
proc_searchfordupes_with_pixels "060_2160"  # <-- look for best releases with 2160 pixels in common
#proc_searchfordupes_with_pixels "070_1080" "FORCE"
proc_searchfordupes_with_pixels "070_1080"  # <-- and 1080
#proc_searchfordupes_with_pixels "080_720" "FORCE"
proc_searchfordupes_with_pixels "080_720"  # <-- and 720
#proc_searchfordupes "FORCE" "FORCE"
#proc_searchfordupes   # <-- you can also comment 2160,1080,720 and only run this one to keep the best quality
proc_delete_dead_symlink
```
Once everything is as you've expected, change the config one last time to go into destructive mode :)
```
#proc_create_database
proc_remove_non_existent
proc_makelist
proc_insertintodatabase
proc_searchfordupes_with_pixels "060_2160" "FORCE"
#proc_searchfordupes_with_pixels "060_2160"
proc_searchfordupes_with_pixels "070_1080" "FORCE"
#proc_searchfordupes_with_pixels "070_1080"
proc_searchfordupes_with_pixels "080_720" "FORCE"
#proc_searchfordupes_with_pixels "080_720"
#proc_searchfordupes "FORCE" "FORCE"  # <-- or this
#proc_searchfordupes
proc_delete_dead_symlink
```

# Run chrooted:
- chroot /jail/glftpd /db/moviedupes.sh
- chroot /jail/glftpd /db/tvdupes.sh


# More explanation
The basics are simple. Strip every release of it's properties. Lucky for us, these people are very specific about their "tagging" which makes it easy to extract the fields.
```
<movie name>(<proper|repack|rerip|etc>)(<dynamic range>)<pixels><source><codec>-<group>
or
<serie name><season><episode>(<proper|repack|rerip|etc>)<pixels><source><codec>-<group>
```
And additional data, like video bitrate for example, can be extracted with external utilities.  
Next is placing the values in a database so it can easilly comparted/ordered by. Remember: HIGHER values are WORSE (except for video bitrate, but that one goes automatically).  
source:  
"009_uhd"  
"010_bluray"  
"011_hddvd"  
"020_web-dl"  
"040_webrip"  
"030_web"  
"090_hdtv"  
"999_unknown"  
  
resolution:  
"060_2160"  
"070_1080"  
"080_720"  
  
codec:  
"040_h265"  
"045_x265"  
"050_h264"  
"055_x264"  
"999_unknown"  
  
dynamic range:  
"040_hdr"  
"045_hdr10plus"  
"110_dolbyvision"  <-- doesn't seem to get a lot of support, hence rated worse than sdr  
"100_sdr"  
  
downvote:  
"100_ok_group"  <-- 100 is the default  
"090_super_group" <-- but you can "upvote" groups you really like  
"110_lame_group"  <-- or "downvote" if every release is basically crap  

specialtags:  
"12_rerip"  
"07_proper_real_rerip"  
"08_repack_proper"  
"09_proper_repack"  
"10_real_repack"  
"11_repack"  
"09_real_proper"  
"10_proper"  
"09_real"  
"90_no_tags"  

If all the properties are the same, then it will look for the date it was created on the harddrive.

The real choice is made with the 'order by' statement in the searchfordupes functions.  
Here is the default:
```
order by pixels,source,codec,dynamicrange,downvote,specialtag,videobitrate DESC,created,internal
```
You can play around with it, e.g. if you always want the highest videobitreate to win, dispite the source for example.  



Easy, right?
