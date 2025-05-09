#!/bin/sh

show_usage () {
    cat <<EOT
Usage: $0 <mode> [<link>] [...args]

mode:               main command to execute. Select from the following list:

  build <link> <git_dir> [zip_file[:subdir]] ...
                    construct a new build from a subfolder of a git project,
                    optionally add contents of one or more zip archives (or
                    their subdirectories) and execute scripts if provided in
                    SCRIPT_AFTER_BUILD and SCRIPT_AFTER_DIFF env variables; set
                    owner on build folder (specified in OWNER env variable,
                    default: www-data)
  diff <link>       show side-by-side diff of current build with the most
                    recent build
  diff-list <link>  show a list of files that differ between the current
                    build and the most recent build
  drop-last <link>  delete folder with the most recent build (if not current)
  release <link>    switch current link to the most recent build
  rollback <link>   switch current link to the previous build
  clean <link> [<N>]  remove all but the N most recent build folders
                    (default: 5)
  current <link>    show current link target
  list              show a list of available doc roots in base folder
                    (specified in BASE_WWW env variable, default: /var/www)
  self-update       pull the new version of deploy script from git

link:               symbolic link name in base www folder (specified in
                    BASE_WWW env variable, default: /var/www), pointing to the
                    current build docroot ("site.net", "example.com", etc.)

EOT
}

# outputs all directories for the link, in created order
# $1 = link name with base dir, ex: /var/www/site.net
link_dirs () {
    ls -1drc "$1-"* |grep "$1-[^-]\+-[^-]\+\$"
}

# outputs the last created directory for the link, ex: site.net-250101-000000
# $1 = link name with base dir, ex: /var/www/site.net
last_link_dir () {
    echo $(basename "$(link_dirs "$1" |tail -1)")
}

BASE_WWW=${BASE_WWW:-/var/www}
OWNER=${OWNER:-www-data}
MODE=$1
LINK=$2

case "$MODE" in
  (list|self-update)
    ;;

  (*)
    [ -n "$LINK" ] || {
      show_usage
      echo "Missing link argument" >>/dev/stderr
      exit 1
    }

    [ -L "$BASE_WWW/$LINK" ] || {
      show_usage
      echo "Provided link '$LINK' is not a symlink in $BASE_WWW" >>/dev/stderr
      exit 1
    }
    ;;
esac

case "$MODE" in
  (build)
    # verify arguments
    GIT_FOLDER="$3"

    [ -d "$GIT_FOLDER" ] || {
      echo "Git folder '$GIT_FOLDER' does not exist" >>/dev/stderr
      exit 1
    }

    # define vars
    NEXT_NAME=$LINK-$(date +%y%m%d-%H%M%S)
    BUILD_FOLDER="$BASE_WWW/$NEXT_NAME"

    # pull sources
    echo pull "$GIT_FOLDER" sources...
    git -C "$GIT_FOLDER" pull

    # create build folder from updated sources
    echo copy "$GIT_FOLDER" to the build folder "$BUILD_FOLDER"...
    mkdir "$BUILD_FOLDER"
    rsync -aC "$GIT_FOLDER/" "$BUILD_FOLDER/"

    while [ -n "$4" ]
    do
      BUILD_FILE=${4%%:*}
      BUILD_SUBFOLDER=${4#*:}
      shift

      [ ! -r "$BUILD_FILE" ] && {
        echo "Build file '$BUILD_FILE' does not exist" >>/dev/stderr
        continue
      }

      if [ -d "$BUILD_FILE" ]
      then
        echo merge contents from folder $BUILD_FILE/ into build folder $BUILD_FOLDER/...
        rsync -aC "$BUILD_FILE/" "$BUILD_FOLDER/"
      else
        echo merge contents from $BUILD_FILE:/$BUILD_SUBFOLDER into build folder $BUILD_FOLDER...
        unzip -q "$BUILD_FILE" -d "/tmp/$NEXT_NAME"
        [ -d "/tmp/$NEXT_NAME/$BUILD_SUBFOLDER" ] || {
          echo "Correct build subfolder is required, '$BUILD_SUBFOLDER' does not exist in '$BUILD_FILE'" >>/dev/stderr
          rm -rf "/tmp/$NEXT_NAME"
          rm -rf "$1"
          continue
        }
        rsync -aC "/tmp/$NEXT_NAME/$BUILD_SUBFOLDER/" "$BUILD_FOLDER/"
        rm -rf "/tmp/$NEXT_NAME"
      fi
    done

    # set build folder owner
    echo setting "$OWNER" as build owner...
    chown -R "$OWNER":www-data "$BUILD_FOLDER"

    # execute SCRIPT_AFTER_BUILD if provided
    if [ -x "${SCRIPT_AFTER_BUILD}" ]
    then
      "$SCRIPT_AFTER_BUILD" "$BUILD_FOLDER" "$BASE_WWW/$LINK" || {
        echo "Error running SCRIPT_AFTER_BUILD from $SCRIPT_AFTER_BUILD" >>/dev/stderr
        exit 1
      }
    fi

    # check difference with current build
    echo checking build difference with current folder...
    diff -r --ignore-all-space --strip-trailing-cr --no-dereference "$BASE_WWW/$LINK/" "$BUILD_FOLDER/" >/dev/null && {
      echo "New build is the same as current one, removing" >>/dev/stderr
      rm -rf "$BUILD_FOLDER"
      exit 1
    }

    # execute SCRIPT_AFTER_DIFF if provided
    if [ -x "${SCRIPT_AFTER_DIFF}" ]
    then
      "$SCRIPT_AFTER_DIFF" "$BUILD_FOLDER" "$BASE_WWW/$LINK" || {
        echo "Error running SCRIPT_AFTER_DIFF from $SCRIPT_AFTER_DIFF" >>/dev/stderr
        exit 1
      }
    fi

    ;;

  (diff)
    CURR_NAME=$(readlink "$BASE_WWW/$LINK")
    NEXT_NAME=$(last_link_dir "$BASE_WWW/$LINK")
    BUILD_FOLDER=$BASE_WWW/$NEXT_NAME

    [ "$CURR_NAME" = "$NEXT_NAME" ] && {
      echo "Current link $LINK already points to the most recent build" >>/dev/stderr
      exit 1
    }

    echo display diff of $BASE_WWW/$CURR_NAME with $BASE_WWW/$NEXT_NAME
    diff -yr --suppress-common-lines --ignore-all-space --strip-trailing-cr --no-dereference -W "$(tput cols)" \
      "$BASE_WWW/$CURR_NAME/" "$BASE_WWW/$NEXT_NAME/" |less
    ;;

  (diff-list)
    CURR_NAME=$(readlink "$BASE_WWW/$LINK")
    NEXT_NAME=$(last_link_dir "$BASE_WWW/$LINK")
    BUILD_FOLDER=$BASE_WWW/$NEXT_NAME

    [ "$CURR_NAME" = "$NEXT_NAME" ] && {
      echo "Current link $LINK already points to the most recent build" >>/dev/stderr
      exit 1
    }

    echo display summary diff of $BASE_WWW/$CURR_NAME with $BASE_WWW/$NEXT_NAME
    diff -qr --ignore-all-space --strip-trailing-cr --no-dereference \
      "$BASE_WWW/$CURR_NAME/" "$BASE_WWW/$NEXT_NAME/"
    ;;

  (drop-last)
    CURR_NAME=$(readlink "$BASE_WWW/$LINK")
    NEXT_NAME=$(last_link_dir "$BASE_WWW/$LINK")

    [ "$CURR_NAME" = "$NEXT_NAME" ] && {
      echo "Current link $LINK points to the most recent build, rollback first" >>/dev/stderr
      exit 1
    }

    echo remove $BASE_WWW/$NEXT_NAME...
    rm -rf "$BASE_WWW/$NEXT_NAME"
    ;;

  (release|commit)
    CURR_NAME=$(readlink "$BASE_WWW/$LINK")
    NEXT_NAME=$(last_link_dir "$BASE_WWW/$LINK")

    [ "$CURR_NAME" = "$NEXT_NAME" ] && {
      echo "Current link $LINK already points to the most recent build" >>/dev/stderr
      exit 1
    }

    echo switch current link from $BASE_WWW/$CURR_NAME to $BASE_WWW/$NEXT_NAME...
    cd "$BASE_WWW"
    rm "$LINK"
    ln -s "$NEXT_NAME" "$LINK"
    ;;

  (rollback)
    CURR_NAME=$(readlink "$BASE_WWW/$LINK")
    PREV_NAME=$(basename "$(link_dirs "$BASE_WWW/$LINK" |awk -v "CURR=$BASE_WWW/$CURR_NAME" '$0==CURR {exit} {prev=$0} END {print prev}')")

    [ -z "$PREV_NAME" ] && {
      echo "Cannot rollback: '$CURR_NAME' is the earliest available build" >>/dev/stderr
      exit 1
    }

    echo rollback current link from $BASE_WWW/$CURR_NAME to $BASE_WWW/$PREV_NAME...
    cd "$BASE_WWW" || {
      echo "Cannot cd to: '$BASE_WWW'" >>/dev/stderr
      exit 1
    }
    rm "$LINK"
    ln -s "$PREV_NAME" "$LINK"
    ;;

  (clean)
    N_KEEP=${3:-5}
    echo remove all but the last $N_KEEP $LINK builds...
    T_FILE=$(mktemp)
    link_dirs "$BASE_WWW/$LINK" |head -n -"$N_KEEP" |tee "$T_FILE" |xargs sudo rm -rf
    cat "$T_FILE"
    rm "$T_FILE"
    ;;

  (current)
    readlink "$BASE_WWW/$LINK"
    ;;

  (list)
    find "$BASE_WWW/" -maxdepth 1 -type l -exec sh -c 'echo "{}"; ls -1drc "{}"-*' ';' |xargs ls -Ffld
    ;;

  (self-update)
    if [ -L "$0" ]; then cd "$(dirname "$(readlink "$0")")"; else cd "$(dirname "$0")"; fi
    git pull
    ;;

  (*)
    show_usage
    echo "Unknown operating mode" >>/dev/stderr
    exit 1
    ;;
esac
