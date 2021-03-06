#!/bin/sh

require() {
  packages=()
  package_paths=()

  local starting_dir="$(pwd)"

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
          if command -v "$package" >/dev/null 2>&1; then
            printf "\e[0;96mcoral\e[0m \e[0;31mERR!\e[0m \e[0;35mrequire\e[0m \"$package\" is already defined on your system!\n"
            continue
          fi
          require_file "$package" "$package_path"
          continue
        fi

        if [ -d "$package" ]; then
          package_path="$(dirname $followed)/$package/index.sh"
          if command -v "$package" >/dev/null 2>&1; then
            printf "\e[0;96mcoral\e[0m \e[0;31mERR!\e[0m \e[0;35mrequire\e[0m \"$package\" is already defined on your system!\n"
            continue
          fi
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
        cd "$modules_directory"
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

        while [ ! -d "$package_directory" ]; do
          modules_directory=${modules_directory%/*}
          package_directory="$modules_directory/shell_modules/$package"
          if [ "$package_directory" = "/" ]; then
            echo "no package \"$package\"!"
            exit
          fi
        done

        if [ ! -f "$package_directory/package.sh" ]; then
          echo "no package.json!"
          exit
        fi

        . "$package_directory/package.sh"
        main=${main:-"index.sh"}
        package_path="$package_directory/$main"

        packages=("${packages[@]} $package")
        package_paths=("${package_paths[@]} $package_path")

        if command -v "$package" >/dev/null 2>&1; then
          printf "\e[0;96mcoral\e[0m \e[0;31mERR!\e[0m \e[0;35mrequire\e[0m \"$package\" is already defined on your system!\n"
          continue
        fi
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
  for function in $functions_string; do
    case "$function" in
      require|require_file|copy_function|rename_function|_*)
        continue
        ;;

      *)
        old_function="_${RANDOM}_$function"
        old_function_definition="$(declare -f $function)"
        eval "${old_function_definition/$function/$old_function}"
        unset -f "$function"
        alias $function="$old_function"

        new_function="_${RANDOM}_${package_no_hyphen}_${old_function}"
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

  cd "$starting_dir"
  . "$temporary"
}
