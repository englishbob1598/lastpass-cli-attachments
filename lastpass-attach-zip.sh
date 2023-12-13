#!/bin/bash
#################################################
# Note, this was inspired by the original get attachment script work by "mindrunner" on Github - many thanks
# Thanks also to the contributors to the lpass-cli, this would be pointless without your efforts!
# https://github.com/mindrunner/lastpass-attachment-exporter/blob/master/lpass-att-export.sh
# Tweaked to only check for attachments and cycle through and to deal with spaces in folders and files
# Will try to improve the documentation and details another day... but hopwfully clear enough to be useful
# You need to have lpass cli and zip/unzip installed as prerequisites to run
# 
#################################################
# Configure the debug options - which will print debugging messages
debug=0
if [ "$1" == "-d" ]; then
    debug=1
fi
# Set home directory to users home dir
home_dir=$HOME
# set the export directory where stuff will be temporarily downloaded
export_dir="lpass-export"
# Zip folder wher the atteachment zip will be put
zip_folder="${home_dir}"
zip_folder="${home_dir}/lp_archive"
# set a variable for the path - to make life easier
export_path="${home_dir}"/"${export_dir}"
echo "$export_path"
# Create the export directory (-p no error if existing and create parents)
mkdir -p "$export_path"
# Change into the export directory
if eval cd "${export_path}" ; then
    if [ "$debug" == "1" ] ; then
        echo "change dir completed to $export_path"
    fi
  else
  echo "failed to change dir to $export_path - PROBLEM"
  exit
fi

# Use the export command to identify all items with attachments
for id_attachment in $(lpass export --fields="id,attachpresent"); do
    # Select the item ID
    id=$(echo "$id_attachment" | awk -F, '{print $1}')
    # Select the has attachment binary value
    att_bin=$(echo "$id_attachment" | awk -F, '{printf $2}' | tr -d '\r')
    if [ "$debug" == "1" ] ; then
        echo "id = +$id+"
        echo "att_bin = +${att_bin}+"
    fi
    # Use the "Has attachment binary" to only loop on relevant entries
    if [ "$att_bin" == "1" ]; then
        # revert to the root of the export path
        # eval cd "${export_path}"
        # Pull the full record of the entry, attachments are listed individually
        full_record=$(lpass show "${id}")
        if [ "$debug" == "1" ] ; then
            echo "att-bin matched"
            echo "Full Record = __START__${full_record}__END__"
        fi
        # Grab the folder structure from the first line of the entry
        full_folder_name=$(echo "$full_record" | head -1 | awk -F[ '{printf $1}' | sed 's/[ \t]*$//')
        if [ "$debug" == "1" ] ; then
            echo "folder name  = $full_folder_name"
            
        fi
        # dont switch to "eval mkdir" syntax as it stops working with folders with spaces
        mkdir -p "${export_path}/${full_folder_name}"
        if [ "$debug" == "1" ] ; then
            echo "making dir - +${export_path}/${full_folder_namr}+"
        fi
        # Hurrah - we have created the folder structure
        # We are going to extract the attachment ID records based on the att-19digit-5digit format - this was using a personal account and attachment number seem randomise
        # With the corporate version attachment numbers seem to be sequencial - so updated to logic to allow att-19digit-[1 to 5 digits]
        for attid in $(echo "$full_record" | grep -o -E "att-[0-9]{19}-[0-9]{1,5}");do
            # although we have grepped out the specific IDs, we also need the file name too
            attachment_rec=$(echo "$full_record" | grep "$attid")
            # funcky sed to get rid of carriage return and any trailing spaces
            attname=$(echo "${attachment_rec}" | awk -F: '{printf $2}'| tr -d '\r' |sed -e 's/^[ \t]*//')
            # Print the attachment name we are pulling just to keep everyone interested
            echo "downloading attachment - ${attname}"
            # Create the output sting with path and file name
            out="${export_path}/${full_folder_name}/${attname}"
            if [ "$debug" == "1" ] ; then
                echo "attid = $attid"
                echo "att_rec = $attachment_rec"
                echo "attname = $attname"
                echo "out = $out" 
            fi
            # Now we have all the attachment details, we can pull it and save it
            # Remember we are still in the loop for only entries with attachments
            lpass show --attach="${attid}" "${id}" --quiet > "${out}"
        done
    fi
done

if eval cd "${zip_folder}"; then
    if [ "$debug" == "1" ] ; then
        echo "change dir to ${zip_folder}"
    fi
    zip_prefix=$(date +%Y-%m-%d_%H-%M)
    # run a zip commmand to delete the files too
    zipcommmand="zip -mr ${zip_prefix}-LP_attachments.zip ${export_path}"
    if eval "${zipcommmand}" ; then
            echo "zipped attachments to ${zip_prefix}-LP_attachments.zip"
    else
            echo "failed to create zipped attachments to ${zip_prefix}-LP_attachments.zip"
    fi
    else
        echo "failed to change dir to ${zip_folder} - PROBLEM"
    exit
fi
