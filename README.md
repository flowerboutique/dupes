# Dupes - a very special usecase for a friend, in bash
Stores properties of (rarred) movies and series into a sqlite3 database. Then removes duplicates based on their properties, e.g. used codec, videobitrate, dynamic range formats, tags, etc. Can perform deduplication within the same ammount of pixels (e.g. best of 720, best of 1080, best of 2160) or keep the best of all. The initial installation seems like a lot of work, but it's just to get all the dependencies in the right place.

## Requirements
- (chrooted) folder structure like /site/movies/, /site/movie-1080/, /site/movie-2160/, /site/tv-720/, /site/tv-uk-720/, /site/tv-uk-1080/, called sections
- (chrooted) sqlite3
- (chrooted) mediainfo utility to extract media information from files, including rar support
- at this point i'm assuming you have a working glftpd installation in /jail/glftpd probably with pzs-ng installed too

Tested on: Ubuntu 20.04.3 LTS (focal) 

Also known to be working on: Debian 10 (buster)

## Prerequisites
apt install libmediainfo-dev git build-essential sqlite3

# Installation:
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
The initial run should probably have the following function calls:
```
proc_create_database
#proc_remove_non_existent  # <-- has no use, sinice there is no content yet
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
Once everything is as you've expected, change the config one last time:
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






Run chrooted:
- chroot /jail/glftpd /db/moviedupes.sh
- chroot /jail/glftpd /db/tvdupes.sh
