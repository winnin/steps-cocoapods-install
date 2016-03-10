#!/bin/bash

THIS_SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${THIS_SCRIPTDIR}/_bash_utils/utils.sh"
source "${THIS_SCRIPTDIR}/_bash_utils/formatted_output.sh"


function pod_install {
	pod --no-repo-update install

	if [ $? -ne 0 ]; then
	  echo
	  echo "Install failed - spec are likely out of date."
	  echo
	  echo "Updating specs..."
	  pod setup
	  echo "Done updating specs. Retrying install"
	  echo
	  pod --no-repo-update install
	fi

	if [ $? -ne 0 ]; then
	  echo "WARNING: Pod quick install failed! Consider moving back to Bitrise standard cocoapods installer"
	  exit 1
	fi
}

CONFIG_cocoapods_ssh_source_fix_script_path="${THIS_SCRIPTDIR}/cocoapods_ssh_source_fix.rb"

write_section_to_formatted_output "### Searching for podfiles and installing the found ones"

podcount=0
IFS=$'\n'
for podfile in $(find . -type f -iname 'Podfile' -not -path "*.git/*")
do
  podcount=$[podcount + 1]
  echo " (i) Podfile found at: ${podfile}"
  curr_podfile_dir=$(dirname "${podfile}")
  curr_podfile_basename=$(basename "${podfile}")
  echo " (i) Podfile directory: ${curr_podfile_dir}"

  (
    echo
    echo " ===> Pod install: ${podfile}"
    cd "${curr_podfile_dir}"
    fail_if_cmd_error "Failed to cd into dir: ${curr_podfile_dir}"
    ruby "${CONFIG_cocoapods_ssh_source_fix_script_path}" --podfile="${curr_podfile_basename}"
    fail_if_cmd_error "Failed to fix Podfile: ${curr_podfile_basename}"

    if [ -f './Gemfile' ] ; then
      echo
      echo "==> Found 'Gemfile' - using it..."
      bundle install
      fail_if_cmd_error "Failed to bundle install"
      echo
      echo "==> Gemfile specified CocoaPods version:"
      bundle exec pod --version
      fail_if_cmd_error "Failed to get pod version"
    else
      echo "==> System Installed CocoaPods version:"
      pod --version
      fail_if_cmd_error "Failed to get pod version"
    fi

    pod_install
    fail_if_cmd_error "Failed to pod install"
  )
  if [ $? -ne 0 ] ; then
    write_section_to_formatted_output "Could not install podfile: ${podfile}"
    exit 1
  fi
  echo_string_to_formatted_output "* Installed podfile: ${podfile}"
done
unset IFS
write_section_to_formatted_output "**${podcount} podfile(s) found and installed**"
