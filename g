#!/usr/bin/env bash
# %-PURPOSE-%
# perform batch operations on single or multiple git repositories

#
# (c) Copyright 2019-2022 Giorgio Gonnella
#

function parse_list_options {
  if [ "$1" == "--list-operations" ]; then
    echo -n "pl st df lg up ls cd --conf"
    exit 0
  fi

  if [ "$1" == "--list-targets" ]; then
    list_all_targets
    exit 0
  fi

  if [ "$1" == "--list-up-targets" ]; then
    list_up_targets
    exit 0
  fi
}

function parse_conf_option {
  if [ "$1" == "--conf" ]; then
    if [ "$#" -gt 1 ]; then
      echo "--conf shall not be followed by other arguments" > /dev/stderr
      exit 1
    fi
    vi $locations
    exit 0
  fi
}

function list_group_targets {
  while read a b theid therest; do
    echo -n "$theid "
  done < <(grep -P '^!\tgroup\t' $locations)
}

function list_groupset_targets {
  while read a b theid therest; do
    echo -n "$theid "
  done < <(grep -P '^!\tgroupset\t' $locations)
}

function list_repo_targets {
  while read group hns location repo; do
    for hn in ${hns//,/	}; do
      if [ "$hn" == "$target_hn" ]; then
        echo -n "$repo "
      fi
    done
  done < <(grep -P -v '(^#|^!|^\s*$)' ${locations})
}

function list_all_targets {
  list_group_targets
  list_groupset_targets
  list_repo_targets
}

function list_up_targets {
  # similar to list_all_targets, but additionally
  # checks if groups and group sets have allowup=yes
  # and the repository only if belongs to a allowup-group
  allowup_groups=" "
  while read a b theid allowup; do
    if [ "$allowup" == "yes" ]; then
      echo -n "$theid "
      allowup_groups+="$theid "
    fi
  done < <(grep -P '^!\tgroup\t' $locations)
  while read a b theid setdef allowup; do
    if [ "$allowup" == "yes" ]; then
      echo -n "$theid "
    fi
  done < <(grep -P '^!\tgroupset\t' $locations)
  # repository names:
  while read group hns location repo; do
    for hn in ${hns//,/	}; do
      if [ "$hn" == "$target_hn" ]; then
        if [[ "$allowup_groups" =~ " $group " ]]; then
          echo -n "$repo "
        fi
      fi
    done
  done < <(grep -P -v '(^#|^!|^\s*$)' ${locations})
}

function print_usage {
  echo "Batch operations on one or multiple of my git repositories"
  echo
  echo "Usage: $0 (--conf|<op> <target> [<target>...|<commitmsg>])"
  echo
  echo "--conf: edit configuration file"
  echo
  echo "<op>:"> /dev/stderr
  echo "  pl: pull"
  echo "  st: status"
  echo "  df: diff"
  echo "  lg: log"
  echo "  up: upload (adds everything, commits with an optional msg)"
  echo "  ls: list (shows the locations of the repositories)"
  echo "  cd: output a cd command to a repository"
  echo
  echo "Notes:"
  echo "- 'up' is not allowed on all targets! (see configuration file);"
  echo "  it only supports one target; everything after the target ID"
  echo "  is considered to be a commit message"
  echo "- 'cd' only accepts a single repository name"
  echo '  include the g command in `` or $() to change directory'
  echo
  echo "<target>:"
  echo "  group_id:     groups of repos          (e.g. gi)"
  echo "  groupset_id:  sets of groups of repos  (e.g. all)"
  echo "  repo_id:      nickname for a repo      (e.g. notes)"
  echo "  (the IDs are set in the configuration file, separately for each host)"
  echo
  echo "Example usage:"
  echo " > g pl gg gg2"
  echo " > g st all"
  echo " > g lg gi"
  echo " > g up notes created new cheatsheets"
  echo " > g df gg"
  echo ' > $(g cd notes)'
  echo
  echo "hostname:            $target_hn"
  echo "configuration file:  $locations"
  echo
  echo "repo IDs:"
  echo "  $(list_repo_targets)"
  echo "group IDs:"
  echo "  $(list_group_targets)"
  echo "groupset IDs:"
  echo "  $(list_groupset_targets)"
}

function pl {
  cd $location
  origin=$(git remote get-url origin)
  echo "# origin: ${origin}"
  git pull
  cd $backuppwd
}

function st {
  cd $location
  git status --short
  cd $backuppwd
}

function df {
  cd $location
  tmpfile=$(mktemp /tmp/g-script.XXXXXX)
  # show staged and unstaged files
  echo "git diff of" $location > $tmpfile
  echo >> $tmpfile
  git --no-pager diff --color=always HEAD >> $tmpfile
  # show also new files
  while read newfile; do
    git --no-pager diff --color=always --no-index /dev/null $newfile >> $tmpfile
  done < <( git ls-files --others --exclude-standard )
  less -R $tmpfile
  rm $tmpfile
  cd $backuppwd
}

function lg {
  cd $location
  tmpfile=$(mktemp /tmp/g-script.XXXXXX)
  echo "git log of" $location > $tmpfile
  echo >> $tmpfile
  git --no-pager log --color=always \
    --pretty="%C(yellow)%h %C(red)%ci %C(green)%aN %Creset%s" >> $tmpfile
  less -R $tmpfile
  rm $tmpfile
  cd $backuppwd
}

function up {
  cd $location
  git up $commitmsg
  cd $backuppwd
}

function ls {
  return # noop
}

# determine if up operation is allowed for a repo based on group membership
function check_allowup {
  local target_group=$1
  allowup="no"
  groupfound="no"
  while read a b group allowup; do
    if [ "$group" == "$target_group" ]; then
      allowup="$allowup"
      groupfound="yes"
      break
    fi
  done < <(grep -P '^!\tgroup\t' ${locations})
  if [ "$groupfound" == "no" ]; then
    echo "Error: group ${target_group} has no definition" > /dev/stderr
    echo "Repository ${repo} belongs to this group" > /dev/stderr
    echo "See file $locations" > /dev/stderr
    exit 1
  elif [ "$allowup" != "yes" ]; then
    echo "Error: up operation not allowed for group $target_group" > /dev/stderr
    echo "Repository ${repo} belongs to this group" > /dev/stderr
    echo "See header of file $locations" > /dev/stderr
    exit 1
  fi
}

function parse_opcode_and_check_n_targets {
  if [ "$1" != "pl" -a \
       "$1" != "st" -a \
       "$1" != "df" -a \
       "$1" != "lg" -a \
       "$1" != "up" -a \
       "$1" != "ls" -a \
       "$1" != "cd" -o \
       "$2" == "" ]; then
    print_usage > /dev/stderr
    exit 1
  fi
  operation=$1
}

function identify_group_target {
  while read a b groupid allowup; do
    if [ "$target" == "$groupid" ]; then
      scope="group"
      target_groups=$groupid
      if [ "$operation" == "up" -a "$allowup" != "yes" ]; then
        echo "Error: up operation not allowed for group $groupid" > /dev/stderr
        echo "See header of file $locations" > /dev/stderr
        exit 1
      fi
      break
    fi
  done < <(grep -P '^!\tgroup\t' ${locations})
}

function identify_groupset_target {
  while read a b groupset groups allowup; do
    if [ "$target" == "$groupset" ]; then
      scope="groupset"
      target_groups="$groups"
      if [ "$operation" == "up" -a "$allowup" != "yes" ]; then
        echo "Error: up operation not allowed for groupset $groupset" > /dev/stderr
        echo "See header of file $locations" > /dev/stderr
        exit 1
      fi
      break
    fi
  done < <(grep -P '^!\tgroupset\t' ${locations})
}

function identify_target {
  scope=""
  target_groups=""
  target_repo=""
  identify_group_target
  if [ "$scope" == "" ]; then
    identify_groupset_target
  fi
  if [ "$scope" == "" ]; then
    scope="single"
    target_repo=$target
    target_groups=dummy
  fi
}

function repo_header {
  if [ "$operation" == "pl" -o \
       "$operation" == "up" -o \
       "$operation" == "st" -o \
       "$operation" == "ls" ]; then
    echo "== $repo ($location)"
  fi
}

function process_target {
  found="no"
  while read group hns location repo; do
    for hn in ${hns//,/	}; do
      if [ "$hn" == "$target_hn" ]; then
        eval location=$location
        if [ ! -d "$location" ]; then
          echo "Error: location $location does not exist" > /dev/stderr
          echo "offending line in $locations:" > /dev/stderr
          echo -e "$group\t$hn\t$location\t$repo" > /dev/stderr
          exit 1
        fi
        if [ "$scope" == "single" ]; then
          if [ "$repo" == "$target_repo" ]; then
            if [ "$operation" == "up" ]; then check_allowup $group; fi
            repo_header
            $operation
            found="yes"
            break
          fi
        else
          IFS=" "
          for target_group in $target_groups; do
            if [ "$group" == "$target_group" ]; then
              repo_header
              $operation
              found="yes"
            fi
          done
          IFS="	" # set back to TAB
        fi
      fi
    done
  done < <(grep -P -v '(^#|^!|^\s*$)' ${locations})

  if [ "$found" == "no" ]; then
    if [ "$scope" == "single" ]; then
      echo "Error: The location of repository $target_repo on this host ($target_hn) is not available" > /dev/stderr
      echo "Please add it to file ${locations}" > /dev/stderr
      exit 1
    elif [ "$scope" == "group" ]; then
      echo "Error: The locations of repositories of group $target_groups on this host ($target_hn) are not available" > /dev/stderr
      echo "Please add them to file ${locations} as:" > /dev/stderr
      exit 1
    elif [ "$scope" == "groupset" ]; then
      echo "Error: The locations of repositories of groups $target_groups on this host ($target_hn) are not available" > /dev/stderr
      echo "Please add them to file ${locations}" > /dev/stderr
      exit 1
    fi
  fi
}

function parse_targets_and_commitmsg {
  shift
  if [ "$operation" == "up" ]; then
    local IFS=" "
    targets=$1
    shift
    commitmsg=$*
  else
    targets=$*
  fi
}

function run {
  backuppwd=$(pwd)
  for target in $targets; do
    identify_target
    process_target
  done
  cd ${backuppwd}
}

function parse_cd_target {
  if [ "$#" -ne 2 ]; then
    echo "cd operation accepts only a single repoID as target" > /dev/stderr
    exit 1
  fi
  target_repo=$2
}

function process_cd_target {
  while read group hns location repo; do
    for hn in ${hns//,/	}; do
      if [ "$hn" == "$target_hn" ]; then
        if [ "$repo" == "$target_repo" ]; then
          eval location=$location
          export location
          return
        fi
      fi
    done
  done < <(grep -P -v '(^#|^!|^\s*$)' ${locations})
  echo "Error: cd accepts a single target, which must be a repository ID" > /dev/stderr
  echo "The location of repository $target_repo on this host ($target_hn) is not available" > /dev/stderr
  echo "Please add it to file ${locations}" > /dev/stderr
  exit 1
}


IFS="	" # this is a tab
# configuration file
locations=${XDG_CONFIG_DIR-$HOME/.config}/ggscripts/git_repository_locations
default_target_hn=$(hostname) # must be defined before parse_list_options
target_hn=${NETWORK-$default_target_hn} # must be defined before parse_list_options
parse_list_options $1 # special options for autocompletion support
parse_conf_option $*
parse_opcode_and_check_n_targets $1 $2
if [ $operation == "cd" ]; then
  parse_cd_target $*
  process_cd_target
  IFS=" "
  echo cd $location
  exit 0
fi
parse_targets_and_commitmsg $*
run
