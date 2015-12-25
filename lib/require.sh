#!/bin/sh

require() {
  packages=()
  package_paths=()

  for package in "$@"; do
    case "$package" in
      "./"*)
        package="${package#.\/}"
        followed=$(ls -l ${BASH_SOURCE[1]})
        if [ "$followed" != "${followed%"->"*}" ]; then
          followed="${followed#*"-> "}"
        else
          followed="${BASH_SOURCE[1]}"
        fi
        package_path="$(dirname "$followed")/$package.sh"

        if [ -f "$package_path" ]; then
          require_file "$package" "$package_path"
          continue
        fi

        if [ -d "$package" ]; then
          package_path="$(dirname $followed)/$package/index.sh"
          require_file "$package" "$package_path"
          continue
        fi

        echo "couldn't find $package"
        exit
        ;;
      *)
        followed=$(ls -l ${BASH_SOURCE[1]})
        if [ "$followed" != "${followed%"->"*}" ]; then
          followed="${followed#*"-> "}"
        else
          followed="${BASH_SOURCE[1]}"
        fi
        modules_directory="$(dirname "$followed")"
        cd $modules_directory
        modules_directory=$(pwd)

        while [ ! -f "$modules_directory/package.sh" ]; do
          modules_directory=${modules_directory%/*}
          if [ "$modules_directory" = "/" ]; then
            echo "couldn't find shell_modules"
            exit
          fi
        done

        cd $modules_directory

        if [ ! -d "shell_modules" ]; then
          mkdir "shell_modules"
        fi

        package_directory="$modules_directory/shell_modules/$package"

        if [ ! -d "$package_directory" ]; then
          echo "no package \"$package\"!"
          exit
        fi

        if [ ! -f "$package_directory/package.sh" ]; then
          echo "no package.json!"
          exit
        fi

        . "$package_directory/package.sh"
        main=${main:-"index.sh"}
        package_path="$package_directory/$main"

        packages=("${packages[@]} $package")
        package_paths=("${package_paths[@]} $package_path")

        require_file "$package" "$package_path"
        ;;
    esac
  done
}

require_file() {
  file="$2"

  if [ ! -f "$file" ]; then
    echo "couldn't find $1"
    exit
  fi

  . "$file"

  temporary="/tmp/$$"

  package_no_hyphen=${1//-/_}
  echo "$package_no_hyphen() {" >> "$temporary"
  echo "case \"\$1\" in" >> "$temporary"

  functions_string=$(compgen -A function)
  functions=$(echo "$functions_string" | sed ':a;N;$!ba;s/
  / /g')
  for function in $functions; do
    case "$function" in
      require|require_file|copy_function|rename_function|_*)
        continue
        ;;

      *)
        new_function="_${RANDOM}_${package_no_hyphen}_${function}"
        [ "$function" = "main" ] && new_main_function="$new_function"
        alias $new_function="$function"

        echo "$function) $new_function \"\${@:2}\" ;;" >> "$temporary"
        ;;
    esac
  done

  echo "main|\"\") ${new_main_function} \"\${@:2}\" ;;" >> "$temporary"

  # todo: add error formatting/logging
  echo "*) echo \"${1}.\$1 doesn't exist!\"; exit; ;;" >> "$temporary"

  echo "esac" >> "$temporary"
  echo "}" >> "$temporary"

  echo "alias \"$1\"=\"$package_no_hyphen\"" >> "$temporary"

  . "$temporary"
}
