#!/bin/sh

source $(coral bootstrap)

require "coral-util"

require() {
  for package in "$@"; do
    modules_directory=$(coral-util get_modules_directory)

    package_directory="$modules_directory/shell_modules/$package"

    if [ ! -d "$package_directory" ]; then
      echo "no package \"$package\"!"
      exit
    fi

    if [ ! -f "$package_directory/package.sh" ]; then
      echo "no package.json!"
      exit
    fi

    source "$package_directory/package.sh"
    main=${main:-"index.sh"}
    entry_point="$package_directory/$main"

    if [ ! -f "$entry_point" ]; then
      echo "couldn't find entry point for $package"
      exit
    fi

    source "$entry_point"

    temporary="tmp.sh"

    echo "$1() {" >> "$temporary"
    echo "case \"\$1\" in" >> "$temporary"

    functions_string=$(compgen -A function)
    functions=${functions_string//$'\n'/ }
    for function in $functions; do
      if [ "$function" != "require" ]; then
        echo "$function) $function \"\${@:2}\" ;;" >> "$temporary"
      fi
    done

    echo "*) \$(\"\$1\") ;;" >> "$temporary"

    echo "esac" >> "$temporary"
    echo "}" >> "$temporary"

    source "$temporary"
    rm "$temporary"
  done
}
