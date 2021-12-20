# dupes - a very special usecase for a friend, in bash
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
- cp -P /usr/lib/x86_64-linux-gnu/libmediainfo* /jail/glftpd/usr/lib/x86_64-linux-gnu/ (sorry about all the following dependencies. Please, someone explain to me why these are needed?)
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
- git clone this project to this dir
- edit conf files

# Run
Run chrooted:
- chroot /jail/glftpd /db/moviedupes.sh
- chroot /jail/glftpd /db/tvdupes.sh
