#!/bin/bash

# include the CHROOTED path to the .conf file
source /db/moviedupes.conf

proc_delete_dead_symlink() {
  echo "Deleting dead symlinks.."
  for BASEDIR in $BASEDIRS; do
    for i in `find "$BASEDIR" -maxdepth 1 -xtype l`; do
      echo "- $i"
      rm -rf "$i"
    done
  done
}

proc_get_mediainfo_for() {
  local rars=`find $1 -maxdepth 1 -type f -iname *.rar`
  local nr_of_files=`echo $rars | wc -l`
  if [[ $nr_of_files -ne 1 || $rars == "" ]]; then
    echo "warning: too many, or 0 rar files in $1"
  else
    local cachefile=`echo $1 | rev | cut -d"/" -f1 | rev`
    local cachefile="$CACHELOCATION/$cachefile"
    if [ ! -f $cachefile ]; then
      /bin/mediainfo-rar -f $rars >$cachefile
      local resultcode=$?
      if [ ! "$resultcode" -eq "0" ]; then
        if [ -f $cachefile ]; then
          echo "deleted possibly bad file"
          rm $cachefile
        fi
      fi
    fi
  fi
}

proc_get_video_bitrate_for() {
  local cachefile=`echo $1 | rev | cut -d"/" -f1 | rev`
  local TEMPFILE="$CACHELOCATION/$cachefile"
  local start=0
  local whitelines=`grep -n '^$' $TEMPFILE | cut -d":" -f1`
  local subs=""
  local audiotracks=""
  for stop in $whitelines; do
    local length=`echo "$stop-$start" | bc`
    local teller=1
    local section=""
    local a_lang=""

    if [[ $length -gt 1 ]]; then
      while read line; do
        if [[ $teller -eq 1 ]]; then
          if   [[ $line == "Filename"* ]]; then section="intro";
          elif [[ $line == "General" ]]; then section="general";
          elif [[ $line == "Video" || $line == "Video "* ]]; then section="video";
          elif [[ $line == "Audio" || $line == "Audio "* ]]; then section="audio";
          elif [[ $line == "Text" || $line == "Text "* ]]; then section="subs";
          elif [[ $line == "Menu" ]]; then section="menu";
          fi
        fi
        #######################################
        if [[ $section == "video" ]]; then
#          if [[ $line == "Bit rate                                 :"* ]]; then
          if [[ $line == "Bit rate                                 :"* || $line == "Nominal bit rate                         :"* ]]; then
            local v_bitrate=`echo $line | cut -d":" -f2 | sed -e 's/ //g' | sed -e 's/kb\/s//g'`
            if [[ $v_bitrate == *"Mb/s" ]]; then
               v_bitrate=`echo $v_bitrate | sed -e 's/Mb\/s//g'`
               v_bitrate=`echo "$v_bitrate*1024" | bc | cut -d"." -f1`
            fi
       #     if [[ $v_bitrate="" ]]; then
       #       v_bitrate=0
       #     else
              v_bitrate=`echo "$v_bitrate / 1024" | bc`
       #     fi
            break
          fi
        fi
        teller=$((teller+1))
      done <<<$(cat $TEMPFILE | head -n $stop | tail -n $length)
    fi
    start=$stop
  done
  echo "$v_bitrate"
}



proc_makelist() {
  echo "Creating list.. might take a while"
  rm -f $OUTPUTFILE
  STARTLIST=`date`
  echo "- started at:  $STARTLIST"
  for BASEDIR in $BASEDIRS
  do
    echo "  Now scanning: $BASEDIR"
    find $BASEDIR -type d \
    | grep -vi "$SITENAME1" \
    | grep -vi "$SITENAME2" \
    | grep -vi "$SITENAME3" \
    | grep -vi "$SITENAME4" \
    | grep -vi "sample" \
    | grep -vi "/disk[1-9]" \
    | grep -vi "/disc[1-9]" \
    | grep -vi "/cd[1-9]" \
    | grep -vi "/subs" \
    | grep -vi "/dutchsubs" \
    | grep -vi "/dvd[1-9]" \
    | grep -vi "nuked*" \
    | grep -vi "proof" \
    | grep -vi "/cover*" \
    | grep -vi "bonus" \
    | grep -vi "Dutchsub" \
    | grep -vi ".DIRFIX" \
    | grep -vi ".SUBFIX." \
    | grep -vi ".NFO.Fix." \
    | grep -vi ".NFOFIX." \
    | grep -vi ".DiRFiX." \
    | grep -vi ".SUBPACK." \
    | grep -vi "\/score_" \
    | grep -vi ".imdbinfoname" \
    | grep -vi "extrafanart" \
    | grep -vi "\.FiX\-" \
    | grep -vi "\.RARFIX\-" \
    | egrep -v $SKIPPATH \
    >> $OUTPUTFILE
  done
  echo "- finished at: " `date`
}



proc_insertintodatabase() {
IFS="
"
  echo "Interting new records"
#  sqlite3 -cmd ".timeout 1000" $DBFILE "BEGIN TRANSACTION"
  LISTING=`cat $OUTPUTFILE`
  for i in $LISTING; do
    EXISTS=`sqlite3 -cmd ".timeout 1000" $DBFILE "SELECT EXISTS(SELECT * FROM moviedupes WHERE fullpath=\"$i\")"`
    if [ $EXISTS -eq 0 ]; then
      # ismovie must contain .720p., .1080p. or .2160p.
      ismovie=`expr match "$i" '.*\(\.720[pP].*\|\.1080[pP].*\|\.2160[pP].*\)'`

      if [ "$ismovie" ]; then
        echo "- $i"

        ######### GET SOURCE TYPE AND GIVE RATING SO THAT WE CAN SORT IT LATER
        if [ `expr match "$i" '.*\.[Uu][Hh][Dd]\.*'` -gt 0 ]; then
          SOURCE="009_uhd"
        elif [ `expr match "$i" '.*\.[Bb][Ll][Uu][Rr][Aa][Yy]\.*'` -gt 0 ]; then
          SOURCE="010_bluray"
        elif [ `expr match "$i" '.*\.[Hh][Dd][Dd][Vv][Dd]\.*'` -gt 0 ]; then
          SOURCE="011_hddvd"
        elif [ `expr match "$i" '.*\.[Ww][Ee][Bb]\-[Dd][Ll]\.*'` -gt 0 ]; then
          SOURCE="020_web-dl"
        elif [ `expr match "$i" '.*\.[Ww][Ee][Bb][Rr][Ii][Pp]\.*'` -gt 0 ]; then  # webrip above web, otherwise web matches first
          SOURCE="040_webrip"
        elif [ `expr match "$i" '.*\.[Ww][Ee][Bb]\.*'` -gt 0 ]; then
          SOURCE="030_web"
        elif [ `expr match "$i" '.*\.[Hh][Dd][Tt][Vv]\.*'` -gt 0 ]; then
          SOURCE="090_hdtv"
        else
          SOURCE="999_unknown"
        fi
#        echo "dbg - SOURCE - $SOURCE"

        ######### GET PIXELS AND GIVE RATING
        if [ `expr match "$i" '.*\.720[Pp]\.*'` -gt 0 ]; then
          PIXELS="080_720"
        elif [ `expr match "$i" '.*\.1080[Pp]\.*'` -gt 0 ]; then
          PIXELS="070_1080"
        elif [ `expr match "$i" '.*\.2160[Pp]\.*'` -gt 0 ]; then
          PIXELS="060_2160"
        else
          PIXELS="999_unknown"
        fi
#        echo "dbg - PIXELS - $PIXELS"

        ######### GET CODEC AND GIVE RATING
        if [ `expr match "$i" '.*\.[Hh]265\.*'` -gt 0 ]; then
          CODEC="040_h265"
        elif [ `expr match "$i" '.*\.[Xx]265\.*'` -gt 0 ]; then
          CODEC="045_x265"
        elif [ `expr match "$i" '.*\.[Hh]264\.*'` -gt 0 ]; then
          CODEC="050_h264"
        elif [ `expr match "$i" '.*\.[Xx]264\.*'` -gt 0 ]; then
          CODEC="055_x264"
        else
          CODEC="999_unknown"
        fi
#        echo "dbg - CODEC - $CODEC"

        ######### GET DYNAMIC RANGE INFO
        if [ `expr match "$i" '.*\.[Hh][Dd][Rr]\.*'` -gt 0 ]; then
          DYNAMICRANGE="040_hdr"
        elif [ `expr match "$i" '.*\.[Hh][Dd][Rr]10[Pp][Ll][Uu][Ss]\.*'` -gt 0 ]; then
          DYNAMICRANGE="045_hdr10plus"
        elif [ `expr match "$i" '.*\.[Dd][Vv]\.*'` -gt 0 ]; then
          DYNAMICRANGE="110_dolbyvision"
        else
          DYNAMICRANGE="100_sdr"
        fi
#        echo "dbg - DYNAMICRANGE - $DYNAMICRANGE"

        ######### GET MEDIA INFO
        proc_get_mediainfo_for $i
        VBR=$(proc_get_video_bitrate_for $i)
#        echo "dbg - VBR $VBR"

        ######### GET MODIFY DATE
        MODIFY=`stat $i | grep "Modify"`
        MODIFY=$(echo $MODIFY | sed 's/Modify: //g')
#        echo "dbg - MODIFY $MODIFY"

        ######### INTERNAL
        if [ `expr match "$i" '.*\.[Ii][Nn][Tt][Ee][Rr][Nn][Aa][Ll]\.*'` -gt 0 ]; then
          INTERNAL="1_internal"
        else
          INTERNAL="0_non_internal"
        fi
#        echo "dbg - INTERNAL $INTERNAL"

        ######### TAGS
        if [ `expr match "$i" '.*\[Rr][Ee][Aa][Ll].[Rr][Ee][Rr][Ii][Pp]\.*'` -gt 0 ]; then
          SPECIALTAG="11_real_rerip"
        elif [ `expr match "$i" '.*\.[Rr][Ee][Rr][Ii][Pp]\.*'` -gt 0 ]; then
          SPECIALTAG="12_rerip"
        elif [ `expr match "$i" '.*\.[Pp][Rr][Oo][Pp][Ee][Rr]\.[Rr][Ee][Aa][Ll]\.[Rr][Ee][Rr][Ii][Pp]\.*'` -gt 0 ]; then
          SPECIALTAG="07_proper_real_rerip"
        elif [ `expr match "$i" '.*\.[Rr][Ee][Pp][Aa][Cc][Kk]\.[Pp][Rr][Oo][Pp][Ee][Rr]\.*'` -gt 0 ]; then
          SPECIALTAG="08_repack_proper"
        elif [ `expr match "$i" '.*\.[Pp][Rr][Oo][Pp][Ee][Rr]\.[Rr][Ee][Pp][Aa][Cc][Kk]\.*'` -gt 0 ]; then
          SPECIALTAG="09_proper_repack"
        elif [ `expr match "$i" '.*\.[Rr][Ee][Aa][Ll]\.[Rr][Ee][Pp][Aa][Cc][Kk]\.*'` -gt 0 ]; then
          SPECIALTAG="10_real_repack"
        elif [ `expr match "$i" '.*\.[Rr][Ee][Pp][Aa][Cc][Kk]\.*'` -gt 0 ]; then
          SPECIALTAG="11_repack"
        elif [ `expr match "$i" '.*\.[Rr][Ee][Aa][Ll]\.[Pp][Rr][Oo][Pp][Ee][Rr]\.*'` -gt 0 ]; then
          SPECIALTAG="09_real_proper"
        elif [ `expr match "$i" '.*\.[Pp][Rr][Oo][Pp][Ee][Rr]\.*'` -gt 0 ]; then
          SPECIALTAG="10_proper"
        elif [ `expr match "$i" '.*\.[Rr][Ee][Aa][Ll]\.*'` -gt 0 ]; then
          SPECIALTAG="09_real"
        else
          SPECIALTAG="90_no_tags"
        fi
#        echo "dbg - SPECIALTAG $SPECIALTAG"


        ######### GROUP
        RELGROUP=`echo $i | rev | cut -d"-" -f1 | rev`
#        echo "dbg - RELGROUP $RELGROUP"


        ######### DOWNVOTE GROUPS
        if [ `expr match "$i" '.*-TBS'` -gt 0 ]; then
          DOWNVOTE="122_tbs"
        elif [ `expr match "$i" '.*-BAMBOOZLE'` -gt 0 ]; then
          DOWNVOTE="123_bamboozle"
        elif [ `expr match "$i" '.*-CRiMSON'` -gt 0 ]; then
          DOWNVOTE="124_crimson_sucks"
        elif [ `expr match "$i" '.*-AMRAP'` -gt 0 ]; then
          DOWNVOTE="090_amrap"
        else
          DOWNVOTE="100_ok_group"
        fi
#        echo "dbg - DOWNVOTE $DOWNVOTE"


        POS=`awk -v a=$i -v b=$ismovie 'BEGIN{print index(a,b)}'`
        RELEASELENGTH=`expr length $i`
        TERMLENGTH=`expr length $ismovie`
        TILL=`expr $POS - 1`  # -2 would also deletes . on the end, but then Star.S02E17.720p.WEB.x264-TBS would match Stargate.SG-1.S02E17.720p.HDTV.x264-SFM and that is not right
        FIRSTPART=`expr substr $i 1 $TILL | tr [[:upper:]] [[:lower:]] | rev | cut -d "/" -f 1 | rev`
#        echo "dbg - FIRSTPART $FIRSTPART"
        MOVIEBASE=`echo $FIRSTPART |\
           sed -e 's/.[Rr][Ee][Rr][Ii][Pp]//g' |\
           sed -e 's/.[Pp][Rr][Oo][Pp][Ee][Rr]\.[Rr][Ee][Aa][Ll]\.[Rr][Ee][Rr][Ii][Pp]//g' |\
           sed -e 's/.[Rr][Ee][Pp][Aa][Cc][Kk]\.[Pp][Rr][Oo][Pp][Ee][Rr]//g' |\
           sed -e 's/.[Rr][Ee][Pp][Aa][Cc][Kk]//g' |\
           sed -e 's/.[Hh][Dd][Rr]//g' |\
           sed -e 's/.[Dd][Vv]//g' |\
           sed -e 's/.[Rr][Ee][Aa][Ll]\.[Pp][Rr][Oo][Pp][Ee][Rr]//g' |\
           sed -e 's/.[Rr][Ee][Aa][Ll]//g' |\
           sed -e 's/.[Pp][Rr][Oo][Pp][Ee][Rr]//g'`

#        echo "dbg - FIRSTPART $FIRSTPART"

        sqlite3 -cmd ".timeout 1000" $DBFILE "INSERT INTO moviedupes (fullpath,relgroup,moviebase,specialtag,internal,downvote,codec,pixels,source,created,videobitrate,dynamicrange) \
                         values (\"$i\",\"$RELGROUP\",\"$MOVIEBASE\",\"$SPECIALTAG\",\"$INTERNAL\",\"$DOWNVOTE\",\"$CODEC\",\"$PIXELS\",\"$SOURCE\",\"$MODIFY\",\"$VBR\",\"$DYNAMICRANGE\")"
      fi
    fi
  done
#  sqlite3 -cmd ".timeout 1000" $DBFILE "COMMIT";
  echo "Interting new records - DONE"
}

proc_searchfordupes_with_pixels() {
  SQLPIXELS="$1"
  RELS=`sqlite3 -cmd ".timeout 1000" $DBFILE "SELECT DISTINCT moviebase FROM moviedupes WHERE pixels='$SQLPIXELS'"`
  for REL in $RELS; do
    MOVIEBASE=`echo $REL | cut -d"|" -f1`
    OLDERTHAN=`date "+%Y-%m-%d %H:%M:%S" -d "-$DONOTCLEANIFNEWERTHANDAYS days"`
    MATCHES=`sqlite3 -cmd ".timeout 1000" -header $DBFILE "select fullpath,pixels,source,codec,downvote,specialtag,created,internal,videobitrate,dynamicrange from moviedupes \
                                      where pixels='$SQLPIXELS' and moviebase='$MOVIEBASE' and created <= '$OLDERTHAN' \
                                      order by pixels,source,codec,dynamicrange,downvote,specialtag,videobitrate DESC,created,internal"`
    NRMATCHES=`echo "$MATCHES" | wc -l`
    if [ $NRMATCHES -gt 2 ]; then
#      echo "$MATCHES"
      proc_cleanup "$MATCHES" "$2"
    fi
  done
}

proc_searchfordupes() {
  RELS=`sqlite3 -cmd ".timeout 1000" $DBFILE "SELECT DISTINCT moviebase FROM moviedupes"`
  for REL in $RELS; do
    MOVIEBASE=`echo $REL | cut -d"|" -f1`
    OLDERTHAN=`date "+%Y-%m-%d %H:%M:%S" -d "-$DONOTCLEANIFNEWERTHANDAYS days"`
    MATCHES=`sqlite3 -cmd ".timeout 1000" -header $DBFILE "select fullpath,pixels,source,codec,downvote,specialtag,created,internal,videobitrate,dynamicrange from moviedupes \
                                      where moviebase='$MOVIEBASE' and created <= '$OLDERTHAN' \
                                      order by pixels,source,codec,dynamicrange,downvote,specialtag,videobitrate DESC,created,internal"`
    NRMATCHES=`echo "$MATCHES" | wc -l`
    if [ $NRMATCHES -gt 2 ]; then
#      echo "$MATCHES"
      proc_cleanup "$MATCHES" "$2"
    fi
  done
}


proc_cleanup() {
IFS="
"
  MATCHES="$1"
  TELLER=0
  for myline in $MATCHES
  do
    if [ $TELLER -eq 1 ]; then
      BESTREASONSTR=""
      BESTRELPATH=`echo $myline | cut -d "|" -f1 | cut -c 6-`
      BESTRELPIXELS=`echo $myline | cut -d "|" -f2 | cut -d"_" -f2-`
      BESTRELSOURCE=`echo $myline | cut -d "|" -f3 | cut -d"_" -f2-`
      BESTRELCODEC=`echo $myline | cut -d "|" -f4 | cut -d"_" -f2-`
      BESTRELDOWNVOTE=`echo $myline | cut -d "|" -f5 | cut -d"_" -f2-`
      BESTRELSPECIALTAG=`echo $myline | cut -d "|" -f6 | cut -d"_" -f2-`
      BESTRELCREATED=`echo $myline | cut -d "|" -f7 | cut -d"_" -f2- | cut -d"." -f1`
      BESTRELINTERNAL=`echo $myline | cut -d "|" -f8 | cut -d"_" -f2-`
      BESTRELVIDEOBITRATE=`echo $myline | cut -d "|" -f9`
      BESTRELDYNAMICRANGE=`echo $myline | cut -d "|" -f10 | cut -d"_" -f2-`
    elif [ $TELLER -gt 1 ]; then
      BADRELPATH=`echo $myline | cut -d "|" -f1 | cut -c 6-`
      BADRELPIXELS=`echo $myline | cut -d "|" -f2 | cut -d"_" -f2-`
      BADRELSOURCE=`echo $myline | cut -d "|" -f3 | cut -d"_" -f2-`
      BADRELCODEC=`echo $myline | cut -d "|" -f4 | cut -d"_" -f2-`
      BADRELDOWNVOTE=`echo $myline | cut -d "|" -f5 | cut -d"_" -f2-`
      BADRELSPECIALTAG=`echo $myline | cut -d "|" -f6 | cut -d"_" -f2-`
      BADRELCREATED=`echo $myline | cut -d "|" -f7 | cut -d"_" -f2- | cut -d"." -f1`
      BADRELINTERNAL=`echo $myline | cut -d "|" -f8 | cut -d"_" -f2-`
      BADRELVIDEOBITRATE=`echo $myline | cut -d "|" -f9`
      BADRELDYNAMICRANGE=`echo $myline | cut -d "|" -f10 | cut -d"_" -f2-`
      BADREASONSTR=""
      if [ "$BADRELSPECIALTAG" != "$BESTRELSPECIALTAG" ]; then
        BADREASONSTR="$BADRELSPECIALTAG|$BADREASONSTR"
        BESTREASONSTR="$BESTRELSPECIALTAG|$BESTREASONSTR"
      fi
      if [ "$BADRELINTERNAL" != "$BESTRELINTERNAL" ]; then
        BADREASONSTR="$BADRELINTERNAL|$BADREASONSTR"
        BESTREASONSTR="$BESTRELINTERNAL|$BESTREASONSTR"
      fi
      if [ "$BADRELVIDEOBITRATE" != "$BESTRELVIDEOBITRATE" ]; then
        vbrunit="kb/s"
        BADREASONSTR="v:$BADRELVIDEOBITRATE$vbrunit|$BADREASONSTR"
        BESTREASONSTR="v:$BESTRELVIDEOBITRATE$vbrunit|$BESTREASONSTR"
      fi
      if [ "$BADRELDOWNVOTE" != "$BESTRELDOWNVOTE" ]; then
        BADREASONSTR="$BADRELDOWNVOTE|$BADREASONSTR"
        BESTREASONSTR="$BESTRELDOWNVOTE|$BESTREASONSTR"
      fi
      if [ "$BADRELCODEC" != "$BESTRELCODEC" ]; then
        BADREASONSTR="$BADRELCODEC|$BADREASONSTR"
        BESTREASONSTR="$BESTRELCODEC|$BESTREASONSTR"
      fi
      if [ "$BADRELDYNAMICRANGE" != "$BESTRELDYNAMICRANGE" ]; then
        BADREASONSTR="$BADRELDYNAMICRANGE|$BADREASONSTR"
        BESTREASONSTR="$BESTRELDYNAMICRANGE|$BESTREASONSTR"
      fi
      if [ "$BADRELSOURCE" != "$BESTRELSOURCE" ]; then
        BADREASONSTR="$BADRELSOURCE|$BADREASONSTR"
        BESTREASONSTR="$BESTRELSOURCE|$BESTREASONSTR"
      fi
      if [ "$BADRELPIXELS" != "$BESTRELPIXELS" ]; then
        BADREASONSTR="$BADRELPIXELS|$BADREASONSTR"
        BESTREASONSTR="$BESTRELPIXELS|$BESTREASONSTR"
      fi
      if [ "$BADRELCREATED" != "$BESTRELCREATED" ]; then
        if [ -z "$BADREASONSTR" ]; then
          BADREASONSTR="$BADRELCREATED|$BADREASONSTR"
          BESTREASONSTR="$BESTRELCREATED|$BESTREASONSTR"
        fi
      fi
      BADREASONSTR=`echo $BADREASONSTR | rev | cut -c 2- | rev`
      BESTREASONSTR=`echo $BESTREASONSTR | rev | cut -c 2- | rev`
      mycomment="DEL: $BADRELPATH ($BADREASONSTR) | KEEP: $BESTRELPATH ($BESTREASONSTR)"
      echo "$mycomment"
      if [ ! -z "$2" ]; then
        echo `date "+%a %b %d %T %Y"` TURGEN: \"\[Clean \] $mycomment\" >> $GLFTPDLOG
        rm -rf "$CHROOTSITEPATH$BADRELPATH"
      fi
      BADREASONSTR=""
      BESTREASONSTR=""
    fi
    TELLER=`expr $TELLER + 1`
  done
}

proc_create_database() {
  echo "Creating database ..."
  sqlite3 -cmd ".timeout 1000" $DBFILE "DROP TABLE IF EXISTS moviedupes"
  sqlite3 -cmd ".timeout 1000" $DBFILE "CREATE TABLE moviedupes(fullpath TEXT UNIQUE, relgroup TEXT, moviebase TEXT, internal TEXT, specialtag TEXT, downvote TEXT, codec TEXT, pixels TEXT, source TEXT, created TEXT, videobitrate INTEGER, dynamicrange TEXT)"
  echo "Creating database - DONE"
}

proc_remove_non_existent() {
IFS="
"
  echo "Cleaning non-existent records"
  ALLRECORDS=`sqlite3 -cmd ".timeout 1000" $DBFILE "select fullpath from moviedupes"`
  for i in $ALLRECORDS; do
#    local vbr=$(proc_get_video_bitrate_for $i)
#    echo "$i = $vbr"
    if [ ! -d $i ]; then
      echo "! WEG - $i"
      sqlite3 -cmd ".timeout 1000" $DBFILE "DELETE FROM moviedupes WHERE fullpath=\"$i\""
#    else
#      local vbr=$(proc_get_video_bitrate_for $i)
#      echo "$i = $vbr"
    fi
  done
  sqlite3 -cmd ".timeout 1000" $DBFILE "VACUUM"
  echo "Cleaning non-existent records - DONE"
}


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






