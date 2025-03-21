#!/bin/bash
#set -x
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# #   Script for snapshoting and/or replication a zfs dataset locally or remotely using zfs or rsync depending on the destination         # #
# #   (needs Unraid 6.12 or above)                                                                                                        # #
# #   by - SpaceInvaderOne                                                                                                                # # 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
#
# Main Variables
#
####################
#
#Unraid notifications during process (sent to Unraid gui etc)
notification_type="all"  # set to "all" for both success & failure, to "error"for only failure or "none" for no notices to be sent.
notify_tune="yes"  # as well as a notifiction, if sucessful it will play the Mario "achievment tune" or failure StarWars imperial march tune on beep speaker!
                   # sometimes good to have an audiable notification!! Set to "no" for silence. (this function your server needs a beep speaker)
#
####################
# Source for snapshotting and/or replication
source_pool="source_zfs_pool_name"  #this is the zpool in which your source dataset resides (note the does NOT start with /mnt/)
source_dataset="dataset_name"   #this is the name of the dataset you want to snapshot and/or replicate
                                #If using auto snapshots souce pool CAN NOT contain spaces. This is because sanoid config doesnt handle them
source_dataset_auto_select="no"  # Set to "no" to snapshot and replicate only the specified source_dataset, "yes" to auto-select all datasets for these operations
source_dataset_auto_select_exclude_prefix="backup_"	# Prefix to exclude certain datasets from auto-selection. Leave empty to disable exclusion
source_dataset_auto_select_excludes=(
	# List of dataset names to be excluded from auto-selection for snapshotting and replication
	"excluded_dataset"
)
#
####################
#
#zfs snapshot settings
autosnapshots="yes" # set to "yes" to have script auto snapshot your source dataset. Set to "no" to skip snapshotting.
#
#snapshot retention policy (default below works well, but change to suit)
snapshot_hours="0"
snapshot_days="7"
snapshot_weeks="4"
snapshot_months="3"
snapshot_years="0"
#
#sanoid config dir (you should not need to edit this)
sanoid_config_dir="/etc/sanoid/"
####################
#
# remote server variables (leave as is (set to "no") if not backing up to another server)
destination_remote="no" # set to "no" for local backup to "yes" for a remote backup (remote location should be accessable paired with ssh with shared keys)
remote_user="root"  #remote user (an Unraid server will be root)
remote_server="10.10.20.197" #remote servers name or ip
remote_port="" #remote server port (empty = use the default for the target server based on your ssh configuration, or the default ssh port)
#
####################
#
### replication settings
#
replication="zfs"   #this is set to the method for how you want to have the sourcedataset replicated - "zfs" , "rsync" or "none"
#
##########
# zfs replication variables. You do NOT need these if replication set to "rsync" or "none"
destination_pool="dest_zfs_pool_name"  #this is the zpool in which your destination dataset will be created
parent_destination_dataset="dest_dataset_name" #this is the parent dataset in which a child dataset will be created containing the replicated data (zfs replication)
# For ZFS replication syncoid is used. The below variable sets some options for that.
# "strict-mirror" Strict mirroring that both mirrors the source and repairs mismatches (uses --force-delete flag).This will delete snapshots in the destination which are not in the source.
# "basic" Basic replication without any additional flags will not delete snapshots in destination if not in the source
syncoid_mode="strict-mirror"
# When replicating encrypted datasets, syncoid will decrypt the data on the origin and send it to the destination. 
# If the destination is also encrypted, it will be re-encrypted using the destination's settings for key, algorithm, etc.
# If the destination is unencrypted, the data will be stored unencrypted as well.
# Selecting "yes" here will force syncoid to ask ZFS for the raw encrypted data stream, allowing for both slightly faster transfers as well as zero-knowledge replication.
# The destination data will remain encrypted with the original key. Unless the destination also has this key, this preserves data secrecy.
syncoid_send_encrypted_raw="no" 
#
##########
#
# rsync replication variables. You do not need these if replication set to zfs or no
parent_destination_folder="/mnt/user/rsync_backup" # This is the parent directory in which a child directory will be created containing the replicated data (rsync)
rsync_type="incremental" # set to "incremental" for dated incremental backups or "mirror" for mirrored backups
#
####################
#
# This function is to log messages to the standard output
log() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')]" $@ 
}
#
####################
#
# This function is to send messages to Unraid gui etc
#
unraid_notify() {
    local message="$1"
    local flag="$2"
    #
    # Check the notification_type variable
    if [[ "$notification_type" == "none" ]]; then
        return 0  # Exit the function if notification_type is set to 'none'
    fi
    #
    # If notification_type is set to 'error' and the flag is 'success', exit the function
    if [[ "$notification_type" == "error" && "$flag" == "success" ]]; then
        return 0  # Do not process success messages
    fi
    #
    # Determine the severity of the message based on the flag it received
    local severity
if [[ "$flag" == "success" ]]; then
    severity="normal"
    # Play success tune based on the value of 'notify_tune' and 'tune'
    if [[ "$notify_tune" == "yes" ]]; then
        if [[ "$tune" == "2" ]]; then
        # plays the old nokia ring tone (only used on snapshot sucess)
            beep -l 150 -f 1318.51022765 -n -l 150 -f 1174.65907167 -n -l 270 -f 739.988845423 -n -l 240 -f 830.60939516 -n -l 120 -f 1108.73052391 -n -l 150 -f 987.766602512 -n -l 270 -f 587.329535835 -n -l 240 -f 659.255113826 -n -l 150 -f 987.766602512 -n -l 120 -f 880.0 -n -l 270 -f 554.365261954 -n -l 240 -f 659.255113826 -n -l 1050 -f 880.0
        tune="1"
        else
        # plays the Mario achievement tune !! this is the main sucess tune used
            beep -f 130 -l 100 -n -f 262 -l 100 -n -f 330 -l 100 -n -f 392 -l 100 -n -f 523 -l 100 -n -f 660 -l 100 -n -f 784 -l 300 -n -f 660 -l 300 -n -f 146 -l 100 -n -f 262 -l 100 -n -f 311 -l 100 -n -f 415 -l 100 -n -f 523 -l 100 -n -f 622 -l 100 -n -f 831 -l 300 -n -f 622 -l 300 -n -f 155 -l 100 -n -f 294 -l 100 -n -f 349 -l 100 -n -f 466 -l 100 -n -f 588 -l 100 -n -f 699 -l 100 -n -f 933 -l 300 -n -f 933 -l 100 -n -f 933 -l 100 -n -f 933 -l 100 -n -f 1047 -l 400
        fi
    fi
    else
        severity="warning"
        # Play failure tune if notify_tune is set to 'yes'
        if [[ "$notify_tune" == "yes" ]]; then
        # plays the Starwars imperial march tune !!
            beep -l 350 -f 392 -D 100 -n -l 350 -f 392 -D 100 -n -l 350 -f 392 -D 100 -n -l 250 -f 311.1 -D 100 -n -l 25 -f 466.2 -D 100 -n -l 350 -f 392 -D 100 -n -l 250 -f 311.1 -D 100 -n -l 25 -f 466.2 -D 100 -n -l 700 -f 392 -D 100 -n -l 350 -f 587.32 -D 100 -n -l 350 -f 587.32 -D 100 -n -l 350 -f 587.32 -D 100 -n -l 250 -f 622.26 -D 100 -n -l 25 -f 466.2 -D 100 -n -l 350 -f 369.99 -D 100 -n -l 250 -f 311.1 -D 100 -n -l 25 -f 466.2 -D 100 -n -l 700 -f 392 -D 100 -n -l 350 -f 784 -D 100 -n -l 250 -f 392 -D 100 -n -l 25 -f 392 -D 100 -n -l 350 -f 784 -D 100 -n -l 250 -f 739.98 -D 100 -n -l 25 -f 698.46 -D 100 -n -l 25 -f 659.26 -D 100 -n -l 25 -f 622.26 -D 100 -n -l 50 -f 659.26 -D 400 -n -l 25 -f 415.3 -D 200 -n -l 350 -f 554.36 -D 100 -n -l 250 -f 523.25 -D 100 -n -l 25 -f 493.88 -D 100 -n -l 25 -f 466.16 -D 100 -n -l 25 -f 440 -D 100 -n -l 50 -f 466.16 -D 400 -n -l 25 -f 311.13 -D 200 -n -l 350 -f 369.99 -D 100 -n -l 250 -f 311.13 -D 100 -n -l 25 -f 392 -D 100 -n -l 350 -f 466.16 -D 100 -n -l 250 -f 392 -D 100 -n -l 25 -f 466.16 -D 100 -n -l 700 -f 587.32
       fi
    fi
    #
    # Call the Unraid notification script
    /usr/local/emhttp/webGui/scripts/notify -s "Backup Notification" -d "$message" -i "$severity"
}
#
####################
#
# This function performs pre-run checks.
pre_run_checks() {
  # check for essential utilities
  if [ ! -x "$(which zfs)" ]; then
    msg='ZFS utilities are not found. This script is meant for Unraid 6.12 or above (which includes ZFS support). Please ensure you are using the correct Unraid version.'
    log "$msg"
    unraid_notify "$msg" "failure"
    exit 1
  fi
  #
  if [ ! -x /usr/local/sbin/sanoid ]; then
    msg='Sanoid is not found or not executable. Please install Sanoid and try again.'
    log "$msg"
    unraid_notify "$msg" "failure"
    exit 1
  fi
  #
  if [ "$replication" = "zfs" ] && [ ! -x /usr/local/sbin/syncoid ]; then
    msg='Syncoid is not found or not executable. Please install Syncoid plugin and try again.'
    log "$msg"
    unraid_notify "$msg" "failure"
    exit 1
  fi
  #
  # check if the dataset and pool exist
  if ! zfs list -H "${source_path}" &>/dev/null; then
    msg="Error: The source dataset '${source_dataset}' does not exist."
    log "$msg"
    unraid_notify "$msg" "failure"
    exit 1
  fi
  #
  # check if autosnapshots is set to "yes" and source_dataset has a space in its name
  if [[ "${autosnapshots}" == "yes" && "${source_dataset}" == *" "* ]]; then
    msg="Error: Autosnapshots is enabled and the source dataset name '${source_dataset}' contains spaces. Rename the dataset without spaces and try again. This is because although ZFS does support spaces in dataset names sanoid config file doesnt parse them correctly"
    log "$msg"
    unraid_notify "$msg" "failure"
    exit 1
  fi
  #
  local used
  used=$(zfs get -H -o value used "${source_path}")
  if [[ ${used} == 0B ]]; then
    msg="The source dataset '${source_path}' is empty. Nothing to replicate."
    log "$msg"
    unraid_notify "$msg" "failure"
    exit 1
  fi
  #
  if [ "$destination_remote" = "yes" ]; then
    log "Replication target is a remote server. I will check it is available..."
    # Attempt an SSH connection. If it fails, print an error message and exit.
    local -a ssh_flags=("-o" "BatchMode=yes" "-o" "ConnectTimeout=5")
    if [ -n "${remote_port}" ]; then
    	ssh_flags+=("-p" "${remote_port}")
    fi
    if ! ssh "${ssh_flags[@]}" "${remote_user}@${remote_server}" echo 'SSH connection successful' &>/dev/null; then
      msg='SSH connection failed. Please check your remote server details and ensure ssh keys are exchanged.'
      log "$msg"
      unraid_notify "$msg" "failure"
      exit 1
    fi
  else
    log "Replication target is a local/same server."
  fi
  #
  # check script configuration variables
  if [ "$replication" != "zfs" ] && [ "$replication" != "rsync" ] && [ "$replication" != "none" ]; then
    msg="$replication is not a valid replication method. Please set it to either 'zfs', 'rsync', or 'none'."
    log "$msg"
    unraid_notify "$msg" "failure"
    exit 1
  fi

  if [ "$autosnapshots" != "yes" ] && [ "$autosnapshots" != "no" ]; then
    msg="The 'autosnapshots' variable is not set to a valid value. Please set it to either 'yes' or 'no'."
    log "$msg"
    unraid_notify "$msg" "failure"
    exit 1
  fi
  #
  if [ "$destination_remote" != "yes" ] && [ "$destination_remote" != "no" ]; then
    msg="The 'destination_remote' variable is not set to a valid value. Please set it to either 'yes' or 'no'."
    log "$msg"
    unraid_notify "$msg" "failure"
    exit 1
  fi
  #
  if [ "$destination_remote" = "yes" ]; then
    if [ -z "$remote_user" ] || [ -z "$remote_server" ]; then
      msg="The 'remote_user' and 'remote_server' must be set when 'destination_remote' is set to 'yes'."
      log "$msg"
      unraid_notify "$msg" "failure"
      exit 1
    fi
  fi
  #
  if [ "$replication" = "none" ] && [ "$autosnapshots" = "no" ]; then
    msg='Both replication and autosnapshots are set to "none". Please configure them so that the script can perform some work.'
    log "$msg"
    unraid_notify "$msg" "failure"
    exit 1
  fi
  #
  if [ "$replication" = "rsync" ]; then
    if [ "$rsync_type" != "incremental" ] && [ "$rsync_type" != "mirror" ]; then
      msg='Invalid rsync_type. Please set it to either "incremental" or "mirror".'
      log "$msg"
      unraid_notify "$msg" "failure"
      exit 1
    fi
  fi
  # If all checks passed print below
  log "All pre-run checks passed. Continuing..."
}
#
####################
#
# This function will build a Sanoid config file for use with the script
create_sanoid_config() {
  # only make config if autosnapshots is set to "yes"
  if [ "${autosnapshots}" != "yes" ]; then
    return
  fi
  #
  # check if the configuration directory exists, if not create it
  if [ ! -d "${sanoid_config_complete_path}" ]; then
    mkdir -p "${sanoid_config_complete_path}"
  fi
  #
  # check if the sanoid.defaults.conf file exists in the configuration directory, if not copy it from the default location
  if [ ! -f "${sanoid_config_complete_path}sanoid.defaults.conf" ]; then
    cp /etc/sanoid/sanoid.defaults.conf "${sanoid_config_complete_path}sanoid.defaults.conf"
  fi
  #
  # check if a configuration file has already been created from a previous run, if so update any settings if necessary
  if [ -f "${sanoid_config_complete_path}sanoid.conf" ]; then
      update_setting() {
          local key=$1 new_value=$2 current_value
          current_value=$(grep "^$key = " "${sanoid_config_complete_path}sanoid.conf" | awk -F ' = ' '{print $2}')
          if [[ "$current_value" != "$new_value" ]]; then
              sed -i "s/^$key = .*/$key = $new_value/" "${sanoid_config_complete_path}sanoid.conf"
              log "[CONFIG CHANGE] Updated '$key' to '$new_value' in '${sanoid_config_complete_path}sanoid.conf'."
          fi
      }
      update_setting "hourly" "$snapshot_hours"
      update_setting "daily" "$snapshot_days"
      update_setting "weekly" "$snapshot_weeks"
      update_setting "monthly" "$snapshot_months"
      update_setting "yearly" "$snapshot_years"
      return
  fi
#
# this  creates the new configuration file based off variables for retention
  echo "[${source_path}]" > "${sanoid_config_complete_path}sanoid.conf"
  echo "use_template = production" >> "${sanoid_config_complete_path}sanoid.conf"
  echo "recursive = yes" >> "${sanoid_config_complete_path}sanoid.conf"
  echo "" >> "${sanoid_config_complete_path}sanoid.conf"
  echo "[template_production]" >> "${sanoid_config_complete_path}sanoid.conf"
  echo "hourly = ${snapshot_hours}" >> "${sanoid_config_complete_path}sanoid.conf"
  echo "daily = ${snapshot_days}" >> "${sanoid_config_complete_path}sanoid.conf"
  echo "weekly = ${snapshot_weeks}" >> "${sanoid_config_complete_path}sanoid.conf"
  echo "monthly = ${snapshot_months}" >> "${sanoid_config_complete_path}sanoid.conf"
  echo "yearly = ${snapshot_years}" >> "${sanoid_config_complete_path}sanoid.conf"
  echo "autosnap = yes" >> "${sanoid_config_complete_path}sanoid.conf"
  echo "autoprune = yes" >> "${sanoid_config_complete_path}sanoid.conf"
}
#
####################
#
# This fuction will autosnapshot the source dataset using Sanoid
autosnap() {
  # check if autosnapshots is set to "yes" before creating snapshots
  if [[ "${autosnapshots}" == "yes" ]]; then
    # Create the snapshots on the source directory using Sanoid if required
    log "creating the automatic snapshots of ${source_path} using sanoid based off retention policy"
    /usr/local/sbin/sanoid --configdir="${sanoid_config_complete_path}" --take-snapshots
    #
    # check the exit status of the sanoid command 
    if [ $? -eq 0 ]; then
      tune="2"
      unraid_notify "Automatic snapshot creation using Sanoid was successful for source: ${source_path}" "success"
    else
      unraid_notify "Automatic snapshot creation using Sanoid failed for source: ${source_path}" "failure"
    fi
  #
  else
    log "Autosnapshots are not set to 'yes', skipping..."
  fi
}
#
####################
#
# This fuction will autoprune the source dataset using sanoid
autoprune() {
  # rheck if autosnapshots is set to "yes" before creating snapshots
  if [[ "${autosnapshots}" == "yes" ]]; then
   log "pruning the automatic snapshots of ${source_path} using sanoid based off retention policy"
# run Sanoid to prune snapshots based on retention policy
/usr/local/sbin/sanoid --configdir="${sanoid_config_complete_path}" --prune-snapshots
  else
    log "Autosnapshots are not set to 'yes', skipping..."
  fi
}
#
####################
#
# This function  does the zfs replication
zfs_replication() {
  # Check if replication method is set to ZFS
  if [ "$replication" = "zfs" ]; then
    # Check if the destination location was set to remote
    if [ "$destination_remote" = "yes" ]; then
      destination="${remote_user}@${remote_server}:${zfs_destination_path}"
      # check if the parent destination ZFS dataset exists on the remote server. If not, create it.
      local -a ssh_flags=()
      if [ -n "${remote_port}" ]; then
        ssh_flags+=("-p" "${remote_port}")
      fi
      ssh "${ssh_flags[@]}" "${remote_user}@${remote_server}" "if ! zfs list -o name -H '${destination_pool}/${parent_destination_dataset}' &>/dev/null; then zfs create '${destination_pool}/${parent_destination_dataset}'; fi"
      if [ $? -ne 0 ]; then
        unraid_notify "Failed to check or create ZFS dataset on remote server: ${destination}" "failure"
        return 1
      fi
    else
      destination="${zfs_destination_path}"
      # check if the parent destination ZFS dataset exists locally. If not, create it.
      if ! zfs list -o name -H "${destination_pool}/${parent_destination_dataset}" &>/dev/null; then
        zfs create "${destination_pool}/${parent_destination_dataset}"
        if [ $? -ne 0 ]; then
          unraid_notify "Failed to check or create local ZFS dataset: ${destination_pool}/${parent_destination_dataset}" "failure"
          return 1
        fi
      fi
    fi
    # calc which syncoid flags to use, based on syncoid_mode
    local -a syncoid_flags=("-r")
    if [ "${destination_remote}" = "yes" ]; then
       syncoid_flags+=("-sshport" "${remote_port}")
    fi
    case "${syncoid_mode}" in
      "strict-mirror")
       syncoid_flags+=("--delete-target-snapshots" "--force-delete")
        ;;
      "basic")
        # No additional flags other than -r
        ;;
      *)
        log "Invalid syncoid_mode. Please set it to 'strict-mirror', or 'basic'."
        exit 1
        ;;
    esac
    if [ "${syncoid_send_encrypted_raw}" = "yes" ] && [ "$(zfs list -H -o encryption ${source_path})" != "off" ]; then
        syncoid_flags+=("--sendoptions" "w")
    fi
    #
    # Use syncoid to replicate snapshot to the destination dataset
    log "Starting ZFS replication using syncoid with mode: ${syncoid_mode}"
    /usr/local/sbin/syncoid "${syncoid_flags[@]}" "${source_path}" "${destination}"
    if [ $? -eq 0 ]; then
      if [ "$destination_remote" = "yes" ]; then
        unraid_notify "ZFS replication was successful from source: ${source_path} to remote destination: ${destination}" "success"
      else
        unraid_notify "ZFS replication was successful from source: ${source_path} to local destination: ${destination}" "success"
      fi
    else
      unraid_notify "ZFS replication failed from source: ${source_path} to ${destination}" "failure"
      return 1
    fi
  else
    log "ZFS replication not set. Skipping ZFS replication."
  fi
}
#
####################
#
# These below functions do the rsync replication
#
# Gets the most recent backup to compare against (used by below funcrions)
get_previous_backup() {
    if [ "$rsync_type" = "incremental" ]; then
        if [ "$destination_remote" = "yes" ]; then
            local -a ssh_flags=()
            if [ -n "${remote_port}" ]; then
              ssh_flags+=("-p" "${remote_port}")
            fi
            log "Running: ssh ${ssh_flags[@]} ${remote_user}@${remote_server} \"ls ${destination_rsync_location} | sort -r | head -n 2 | tail -n 1\""
            previous_backup=$(ssh "${ssh_flags[@]}" "${remote_user}@${remote_server}" "ls \"${destination_rsync_location}\" | sort -r | head -n 2 | tail -n 1")
        else
            previous_backup=$(ls "${destination_rsync_location}" | sort -r | head -n 2 | tail -n 1)
        fi
    fi
}
#
rsync_replication() {
    local previous_backup  # declare variable 

    IFS=$'\n'
    if [ "$replication" = "rsync" ]; then
        local snapshot_name="rsync_snapshot"
        if [ "$rsync_type" = "incremental" ]; then
            backup_date=$(date +%Y-%m-%d_%H%M)
            destination="${destination_rsync_location}/${backup_date}"
        else
            destination="${destination_rsync_location}"
        fi
        #
        do_rsync() {
            local snapshot_mount_point="$1"
            local rsync_destination="$2"
            local relative_dataset_path="$3"
            get_previous_backup
            local link_dest_path="${destination_rsync_location}/${previous_backup}${relative_dataset_path}"
            [ -z "$previous_backup" ] && local link_dest="" || local link_dest="--link-dest=${link_dest_path}"
            log "Link dest value is: $link_dest"
            # Log the link_dest value for debugging
            log "Link dest value is: $link_dest"
            #
            if [ "$destination_remote" = "yes" ]; then
                # Create the remote directory 
                local -a ssh_flags=()
                if [ -n "${remote_port}" ]; then
                  ssh_flags+=("-p" "${remote_port}")
                fi
                [ "$rsync_type" = "incremental" ] && ssh "${ssh_flags[@]}" "${remote_user}@${remote_server}" "mkdir -p \"${rsync_destination}\""
                # Rsync the snapshot to the remote destination with link-dest
                #rsync -azvvv --delete $link_dest -e ssh "${ssh_flags[@]}" "${snapshot_mount_point}/" "${remote_user}@${remote_server}:${rsync_destination}/"
                log "Executing remote rsync: rsync -azvh --delete $link_dest -e ssh \"${ssh_flags[@]}\" \"${snapshot_mount_point}/\" \"${remote_user}@${remote_server}:${rsync_destination}/\""
                rsync -azvh --delete $link_dest -e ssh "${ssh_flags[@]}" "${snapshot_mount_point}/" "${remote_user}@${remote_server}:${rsync_destination}/"

                if [ $? -ne 0 ]; then
                    unraid_notify "Rsync replication failed from source: ${source_path} to remote destination: ${remote_user}@${remote_server}:${rsync_destination}" "failure"
                    return 1
                fi
            else
                # Ensure the backup directory exists
                [ "$rsync_type" = "incremental" ] && mkdir -p "${rsync_destination}"
                # Rsync the snapshot to the local destination with link-dest
              #  rsync -avv --delete $link_dest "${snapshot_mount_point}/" "${rsync_destination}/"
              log "Executing local rsync: rsync -avh --delete $link_dest \"${snapshot_mount_point}/\" \"${rsync_destination}/\""
rsync -avh --delete $link_dest "${snapshot_mount_point}/" "${rsync_destination}/"

                if [ $? -ne 0 ]; then
                    unraid_notify "Rsync replication failed from source: ${source_path} to local destination: ${rsync_destination}" "failure"
                    return 1
                fi
            fi
        }
        #
        log "making a temporary zfs snapshot for rsync"
        zfs snapshot "${source_path}@${snapshot_name}"
        if [ $? -ne 0 ]; then
            unraid_notify "Failed to create ZFS snapshot for rsync: ${source_path}@${snapshot_name}" "failure"
            return 1
        fi
        #
        local snapshot_mount_point="/mnt/${source_path}/.zfs/snapshot/${snapshot_name}"
        do_rsync "${snapshot_mount_point}" "${destination}" ""
        #
        log "deleting temporary snapshot"
        zfs destroy "${source_path}@${snapshot_name}"
        if [ $? -ne 0 ]; then
            unraid_notify "Failed to delete ZFS snapshot after rsync: ${source_path}@${snapshot_name}" "failure"
            return 1
        fi
        #
        # Replication for child sub-datasets
        local child_datasets=$(zfs list -r -H -o name "${source_path}" | tail -n +2)
        #
        for child_dataset in ${child_datasets}; do
            local relative_path=$(echo "${child_dataset}" | sed "s|^${source_path}/||g")
            log "making a temporary zfs snapshot (child) for rsync"
            zfs snapshot "${child_dataset}@${snapshot_name}"
            snapshot_mount_point="/mnt/${child_dataset}/.zfs/snapshot/${snapshot_name}"
            child_destination="${destination}/${relative_path}"
            do_rsync "${snapshot_mount_point}" "${child_destination}" "/${relative_path}"
            zfs destroy "${child_dataset}@${snapshot_name}"
        done
        #
        # Send a single success Unraid notification after all datasets (main and child) have been processed.
        if [ "$destination_remote" = "yes" ]; then
            unraid_notify "Rsync ${rsync_type} replication was successful from source: ${source_path} to remote destination: ${remote_user}@${remote_server}:${destination}" "success"
        else
            unraid_notify "Rsync ${rsync_type} replication was successful from source: ${source_path} to local destination: ${destination}" "success"
        fi
    fi
}

####################
#
# Update configs for specific dataset
#
update_paths() {
    local source_dataset_name="$1"

    source_dataset=$source_dataset_name
    source_path="$source_pool"/"$source_dataset"
    zfs_destination_path="$destination_pool"/"$parent_destination_dataset"/"$source_pool"_"$source_dataset"
    destination_rsync_location="$parent_destination_folder"/"$source_pool"_"$source_dataset"
    sanoid_config_complete_path="$sanoid_config_dir""$source_pool"_"$source_dataset"/
}
#
####################
#
# This function iterates over selected datasets to perform snapshotting and replication tasks
#
run_for_each_dataset() {

  # Array to hold dataset names for processing
  declare -a dataset_names

  if [[ "$source_dataset_auto_select" == "no" ]]; then
    # Directly use the specified dataset if auto-selection is disabled
    selected_source_datasets=("$source_dataset")
  else
    # Filter datasets based on exclusion rules if auto-selection is enabled
    if [[ -z "$source_dataset_auto_select_exclude_prefix" ]]; then
      # Select all datasets if no exclusion prefix is specified
      while IFS= read -r line; do
        # Extract dataset name
        dataset_name=$(echo "$line" | awk -F'/' '{print $NF}')
        if [[ ! " ${source_dataset_auto_select_excludes[@]} " =~ " ${dataset_name} " ]]; then
          # Add dataset to the list if not excluded
          selected_source_datasets+=("$line")
        else
          log "Exclude dataset $dataset_name"
        fi
        done < <(zfs list -r -o name -H $source_pool | awk -F'/' -v pool="$source_pool" '($0 ~ pool && NF==2) {print $2}')
    else
      # Exclude datasets starting with the specified prefix
      log "Skipping datasets with names starting with {$source_dataset_auto_select_exclude_prefix}"
      while IFS= read -r line; do
        # Extract dataset name
        dataset_name=$(echo "$line" | awk -F'/' '{print $NF}')
        if [[ ! " ${source_dataset_auto_select_excludes[@]} " =~ " ${dataset_name} " ]]; then
          # Add dataset to the list if not excluded
          selected_source_datasets+=("$line")
      else
        log "Exclude dataset $dataset_name"
      fi
      done < <(zfs list -r -o name -H $source_pool | awk -F'/' -v pool="$source_pool" -v prefix="$source_dataset_auto_select_exclude_prefix" '($0 ~ pool && NF==2 && $2 !~ ("^" prefix)) {print $2}')
    fi
  fi
  log "\tSelected datasets:"
  printf '\t\t%s\n' "${selected_source_datasets[@]}"

  # Perform pre-run checks, create sanoid configs, snapshot, prune, and replicate for each selected dataset.
  for source_dataset_name in "${selected_source_datasets[@]}"; do
    update_paths $source_dataset_name
    log "Performing pre-run checks for $source_dataset_name"
    pre_run_checks
    log "Creating sanoid config for $source_dataset_name"
    create_sanoid_config
  done

  for source_dataset_name in "${selected_source_datasets[@]}"; do
    update_paths $source_dataset_name
    log "Performing autosnapshot for $source_dataset_name"
    autosnap
  done

  for source_dataset_name in "${selected_source_datasets[@]}"; do
    update_paths $source_dataset_name
    log "Performing autoprune for $source_dataset_name"
    autoprune
    log "Performing rsync replication for $source_dataset_name"
    rsync_replication
    log "Performing ZFS replication for $source_dataset_name"
    zfs_replication
  done
}

#
########################################
#
# Execute the main function to start the process
run_for_each_dataset
