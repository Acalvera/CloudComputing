#!/bin/bash
# ------------------------------------------------------------------------------
# File: cli_interface.sh
# Author: Alejandro Calvera Tonin
# Date: May 2025
# Description: Script to launch a new instance on Chameleon Cloud using the CLI
#    interface and Openstack
# ------------------------------------------------------------------------------

# Check if the file to use the CLI interface is on the same directory
regex='^CHI-[0-9]+-openrc\.sh$'
found=0
# Loop through all files in the current directory to find the CLI file
for file in *; do
  if [[ -f "$file" && "$file" =~ $regex ]]; then
    found=1
    cli_file="$file"
    break
  fi
done

if [[ $found -eq 0 ]]; then # CLI interface file not found 
  echo "========================================================================"
  echo "==== Missing file to use the CLI interface, exiting the script ...  ===="
  echo "========================================================================"
  exit 1
fi

# If CLI interface file is downloaded and on same directory, execute it
echo "========================================="
echo "==== Accessing the CLI interface ... ===="
echo "========================================="
source $cli_file
echo

# Prevent the script from finishing after doing the selected operation
while true; do
	
  # Show option menu to select an operation
	while true; do
		echo "============================================"
		echo "====   SELECT AN OPERATION TO PERFORM   ===="
		echo "============================================"
		echo "== 1. Create a CUSTOM new instance        =="
		echo "== 2. Create a PREDETERMINED new instance =="
		echo "== 3. REMOVE an existing instance         =="
    echo "== 4. LIST the available instances        =="
		echo "== 5. EXIT the script                     =="
		echo "============================================"
		read -p "=====> : " choice

		# Check the input of the user
		if [[ "$choice" =~ ^[1-5]$ ]]; then
			break
		fi	
	done

	# The user chose to create a new custom instance
	if [ "$choice" -eq 1 ]; then
		echo
		echo "==========================================="
		echo "==== Creation of a new CUSTOM instance ===="
		echo "==========================================="

    # Ask the user if wants to install the monitoring tools on the new instance
    while true; do
      echo "======================================================================================================"
      echo "==== Do you want to install the suggested monitoring tools on the instance that is to be created? ===="
      echo "======================================================================================================"
      echo "== 1. Yes                                                                                           ==" 
      echo "== 2. No                                                                                            =="
      echo "======================================================================================================"
      read -p "=====> : " tools
      echo

      # Check the user input
      if [[ "$tools" =~ ^[1-2]$ ]]; then 
        if [[ "$tools" -eq 1 ]]; then
          echo "============================================================================"
          echo "====                               WARNING                              ===="
          echo "============================================================================"
          echo "==== - Make sure the security group you choose on the following steps   ===="
          echo "====     has the following ports open: 3000, 9000, 9100 and 9090        ===="
          echo "====     (Choose security group \"Monitoring\" if available)            ===="
          echo "==== - Make sure the script \"monitoring_set_up.sh\" is downloaded and  ===="
          echo "====     on the same directory as this script, otherwise the monitoring ===="
          echo "====     tools will not be installed.                                   ===="
          echo "============================================================================"
          read -p "=====> Press ENTER to continue: " enter
          echo
        fi
        break
      fi
    done

		# Show all the available flavors
		echo "==================================================="
		echo "==== Listing the flavors list, please wait ... ===="
		echo "==================================================="
		openstack flavor list
		if [[ $? -ne 0 ]]; then
			echo "=====> ERROR: Could not list the flavors."
			exit 1
		fi
		# Request a flavor to the user.
		while true; do
			read -p "=====> Enter the ID of the desired flavor for the instance: " flavor

			# Skip if input is empty
			if [[ -z "$flavor" ]]; then
				echo "=====> Empty input is not allowed."
				continue
			fi

			# Chameleon Cloud only has 6 available flavors
			if [[ "$flavor" =~ ^[1-6]$ ]]; then
				break
			else
				echo "=====> The ID introduced is not valid."
			fi
		done
		echo

		# Show all the available images
		echo "============================================="
		echo "==== Listing the images, please wait ... ===="
		echo "============================================="
		# Get the image list, and show it to the user
		images_list=$(openstack image list)
		if [[ $? -ne 0 ]]; then
			echo "=====> ERROR: Could not list the images."
			exit 1
		fi
		echo "$images_list"
		
		# Extract image names into an array for validation
		mapfile -t image_names < <(echo "$images_list" | awk -F'|' '{gsub(/^ +| +$/, "", $3); print $3}')

		# Request an image name to the user
		while true; do
			read -p "=====> Enter the EXACT NAME of the desired image for the instance: " image

			# Skip if input is empty
			if [[ -z "$image" ]]; then
				echo "=====> Empty input is not allowed."
				continue
			fi

			# Check if input matches any valid image name
			valid=false
			for n in "${image_names[@]}"; do
				if [[ "$image" == "$n" ]]; then
					valid=true
					break
				fi
			done

			if [[ "$valid" == true ]]; then
				# Get the corresponding ID
				image_id=$(echo "$images_list" | awk -F'|' -v name="$image" '
				{
					gsub(/^ +| +$/, "", $3)
					gsub(/^ +| +$/, "", $2)
					if ($3 == name) print $2
				}')
				break
			else
				echo "=====> The image name introduced is not valid. "
			fi
		done
		echo

		# Show all the available keypairs
		echo "==============================================="
		echo "==== Listing the keypairs, please wait ... ===="
		echo "==============================================="
		# Get the keypairs list, and show it to the user
		keypairs_list=$(openstack keypair list)
		if [[ $? -ne 0 ]]; then
			echo "=====> ERROR: Could not list the keypairs."
			exit 1
		fi
		echo "$keypairs_list"

		# Extract keypair names into an array for validation
		mapfile -t keypair_names < <(echo "$keypairs_list" | awk -F'|' '{gsub(/^ +| +$/, "", $2); print $2}')
		
		# Request a keypair name to the user
		while true; do
			read -p "=====> Enter the EXACT NAME of the desired key for the instance: " key

			# Skip if input is empty
			if [[ -z "$key" ]]; then
				echo "=====> Empty input is not allowed."
				continue
			fi

			# Check if input matches any valid key name
			valid=false
			for k in "${keypair_names[@]}"; do
				if [[ "$key" == "$k" ]]; then
					valid=true
					break
				fi
			done

			if [[ "$valid" == true ]]; then
        # Name has been found, exit the loop
				break
			else
				echo "=====> The key name introduced is not valid. "
			fi
		done
		echo

		# Show all the available security groups
		echo "======================================================"
		echo "==== Listing the security groups, please wait ... ===="
		echo "======================================================"
		# Get the security groups list, and show it to the user
		security_group_list=$(openstack security group list)
		if [[ $? -ne 0 ]]; then
			echo "=====> ERROR: Could not list the security groups."
			exit 1
		fi
		echo "$security_group_list"

		# Extract security group names into an array for validation
		mapfile -t security_group_names < <(echo "$security_group_list" | awk -F'|' '{gsub(/^ +| +$/, "", $3); print $3}')

		# Request a security group name to the user
		while true; do
			read -p "=====> Enter the EXACT NAME of the desired security group for the instance: " group

			# Skip if input is empty
			if [[ -z "$group" ]]; then
				echo "=====> Empty input is not allowed."
				continue
			fi

			# Check if input matches any valid security group name
			valid=false
			for g in "${security_group_names[@]}"; do
				if [[ "$group" == "$g" ]]; then
					valid=true
					break
				fi
			done

			if [[ "$valid" == true ]]; then
				# Get the corresponding ID
				security_group_id=$(echo "$security_group_list" | awk -F'|' -v name="$group" '
				{
					gsub(/^ +| +$/, "", $3)
					gsub(/^ +| +$/, "", $2)
					if ($3 == name) print $2
				}')
				break
			else
				echo "=====> The security group name introduced is not valid. "
			fi
		done
		echo

		# Request a name for the instance
		read -p "=====> Enter a name for the instance: " name
		echo 

		echo "===================================================="
		echo "==== Creating the new instance, please wait ... ===="
		echo "===================================================="
		# Create the custom instance of the user
    if [[ "$tools" -eq 1 ]]; then # Install monitoring tools on the new instance
      script=monitoring_set_up.sh
      instance=$(openstack server create --format json --flavor $flavor --image $image --key-name $key --security-group $group --user-data $script $name)
    else # Creation of new instance without monitoring tools
		  instance=$(openstack server create --format json --flavor $flavor --image $image --key-name $key --security-group $group $name)
    fi
		if [[ $? -ne 0 ]]; then
			echo "=====> ERROR: Instance creation failed."
			exit 1
		fi
		echo

		# Show all the available floating ips
		echo "===================================================="
		echo "==== Listing the floating IPs, please wait ... ====="
		echo "===================================================="
		# Get the floating ip list, and show it to the user
		floating_ips_list=$(openstack floating ip list)
		if [[ $? -ne 0 ]]; then
			echo "=====> ERROR: Could not list the floating IPs."
			exit 1
		fi
		echo "$floating_ips_list"

		# Extract floating ips into an array for validation
		mapfile -t available_floating_ips < <(echo "$floating_ips_list" | awk -F'|' '{gsub(/^ +| +$/, "", $3); print $3}')
    # EXtract fixed ips into an array for validation
		mapfile -t available_fixed_ips < <(echo "$floating_ips_list" | awk -F'|' '{gsub(/^ +| +$/, "", $4); print $4}')

		# Request a floating ip to the user
		while true; do
			read -p "=====> Enter the EXACT Floating IP address to use for the instance (only unassigned ones are allowed): " ip

			# Skip if input is empty
      if [[ -z "$ip" ]]; then
				echo "=====> Empty input is not allowed."
				continue
			fi

			# Check if input matches any valid floating ip
			valid=false
			for index in "${!available_floating_ips[@]}"; do
				if [[ "$ip" == "${available_floating_ips[$index]}" ]]; then
          # If valid floating ip, check if it is already in use
					if [[ "${available_fixed_ips[$index]}" == "None" ]]; then 
						valid=true
					else
						echo "=====> Selected IP address is already assigned."
					fi
					break
				fi
			done

			if [[ "$valid" == true ]]; then
				break
			else 
				echo "=====> Selected IP address is not valid."
			fi

		done
		echo
		
    # Add the selected ip to the previously created instance
		echo "====================================================="
		echo "==== Adding selected floating IP to instance ... ===="
		echo "====================================================="
    # Get the ID of the instance that was created
		server=$(echo "$instance" | jq -r '.id')
    # Add the floating ip to the instance
		openstack server add floating ip $server $ip
		if [[ $? -ne 0 ]]; then
			echo "=====> ERROR: Could not assign the floating IP to the instance."
			exit 1
		fi

    # Show message of confirmation
    if [[ "$tools" -eq 1 ]]; then # confirmation message if monitoring tools have been installed
      echo "===================================================================================="
      echo "====                       Creation completed successfully                      ===="
      echo "===================================================================================="
      echo "== Use the following IP to access the instance: $ip                    =="
      echo "== Access $ip on port 3000 to monitor the resources of the instance    =="
      echo "== Access $ip on port 9000 to manage the docker containers             =="
      echo "===================================================================================="
      echo
    else
      echo "================================================================="
      echo "====             Creation completed successfully             ===="
      echo "================================================================="
      echo "== Use the following IP to access the instance: $ip =="
      echo "================================================================="
      echo
    fi

	elif [ "$choice" -eq 2 ]; then # The user chose to launch a predetermined instance

    echo
    echo "=================================================="
    echo "==== Creation of a new PREDETERMINED instance ====" 
    echo "=================================================="

    # Show the list of all the predetermined instances
    while true; do
      echo "=========================================="
      echo "==== SELECT AN INSTANCE FROM THE LIST ===="
      echo "=========================================="
      echo "== 1. Ubuntu 24.04                      =="
      echo "== 2. Ubuntu 22.04                      =="
      echo "== 3. Ubuntu 20.04                      =="
      echo "=========================================="
      read -p "=====> : " choice

      # Check the user input
      if [[ "$choice" =~ ^[1-3]$ ]];then
        break
      fi
    done

    # Set up values for the creation of the instance depending on the selected option
    if [[ "$choice" -eq 1 ]]; then
      flavor=3 # Number of flavor corresponding to medium
      image=96d9c658-6540-4796-ae64-54d8ac6c45f8 # ID corresponding to an Ubuntu24.04
      key=LGgram # Name of the selected keypair
      group=Monitoring # Same as "default" security group but with some extra open ports for monitoring
      script=monitoring_set_up.sh # Name of the script to run on instance creation
    elif [[ "$choice" -eq 2 ]]; then
      flavor=3
      image=8c7e0698-58dd-4366-bd71-f1b4dfea5eb8 # ID corresponding to an Ubuntu22.04
      key=LGgram
      group=Monitoring
      script=monitoring_set_up.sh
    else 
      flavor=2
      image=7580b9fb-3693-4574-b875-cfe43918b345 # ID corresponding to an Ubuntu20.04
      key=LGgram
      group=Monitoring
      script=monitoring_set_up.sh
    fi

    echo
    # Request a name for the new instance
    read -p "=====> Enter a name for the instance: " name

    echo
    echo "============================================================================="
    echo "==== Creating the new instance and assigning IP address, please wait ... ===="
    echo "============================================================================="
  
    # Create the new instance according to the selected option
		instance=$(openstack server create --format json --flavor $flavor --image $image --key-name $key --security-group $group --user-data $script $name)
		if [[ $? -ne 0 ]]; then
			echo "=====> ERROR: Instance creation failed."
			exit 1
		fi

    # Set a floating ip to the new instance (the first available floating ip)
		floating_ips_list=$(openstack floating ip list)
		if [[ $? -ne 0 ]]; then
			echo "=====> ERROR: Could not list the floating IPs."
			exit 1
		fi
    
		# Extract floating ips into an array for validation
		mapfile -t available_floating_ips < <(echo "$floating_ips_list" | awk -F'|' '{gsub(/^ +| +$/, "", $3); print $3}')
    # EXtract fixed ips into an array for validation
		mapfile -t available_fixed_ips < <(echo "$floating_ips_list" | awk -F'|' '{gsub(/^ +| +$/, "", $4); print $4}')

    found=false
    # Find the first floating ip available
		for index in "${!available_floating_ips[@]}"; do
			if [[ "${available_fixed_ips[$index]}" == "None" ]]; then 
        found=true
        ip=${available_floating_ips[$index]}
        break 
			fi
		done

    # Check if IP has been found
    if [[ "$found" == false ]];then
      echo "=====> ERROR: No floating IPs are available."
      exit 1
    fi
    
    # Get the ID of the instance that was created
		server=$(echo "$instance" | jq -r '.id')
    # Add the floating ip to the instance
		openstack server add floating ip $server $ip
		if [[ $? -ne 0 ]]; then
			echo "=====> ERROR: Could not assign the floating IP to the instance."
			exit 1
		fi

    # Show message of confirmation
    echo "===================================================================================="
    echo "====                       Creation completed successfully                      ===="
    echo "===================================================================================="
    echo "== Use the following IP to access the instance: $ip                    =="
    echo "== Access $ip on port 3000 to monitor the resources of the instance    =="
    echo "== Access $ip on port 9000 to manage the docker containers             =="
    echo "===================================================================================="
    echo

	elif [ "$choice" -eq 3 ]; then # The user chose to remove an existing instance
		
		echo
		echo "========================================="
		echo "==== Removal of an existing instance ===="
		echo "========================================="

		# Show all the existing instances
		echo "========================================================="
		echo "==== Listing the existing instances, please wait ... ===="
		echo "========================================================="
		# Get the instances list 
		server_list=$(openstack server list)
		if [[ $? -ne 0 ]]; then
			echo "=====> ERROR: Could not list the instances."
			exit 1
		fi
		echo "$server_list"
		
		# Extract instances names into an array for validation
		mapfile -t server_names < <(echo "$server_list" | awk -F'|' '{gsub(/^ +| +$/, "", $3); print $3}')
		
		# Request an instance name to the user
		while true; do
			read -p "=====> Enter the EXACT NAME of the instance to remove: " server
			
			# Skip if input is empty
			if [[ -z "$server" ]]; then
				echo "=====> Empty input is not allowed."
				continue
			fi

			# Check if input matches any valid instances name
			valid=false
			for s in "${server_names[@]}"; do
				if [[ "$server" == "$s" ]]; then
					valid=true
					break
				fi
			done

			if [[ "$valid" == true ]]; then
				# Get the corresponding ID
				server_id=$(echo "$server_list" | awk -F'|' -v name="$server" '
				{
					gsub(/^ +| +$/, "", $3)
					gsub(/^ +| +$/, "", $2)
					if ($3 == name) print $2
				}')
				break
			else
				echo "=====> The instance name introduced is not valid. "
			fi
		done
		echo

		# Remove the selected instance
		echo "====================================================="
		echo "==== Removing selected instance, please wait ... ===="
		echo "====================================================="
    # Remove the instance
		openstack server delete $server
		if [[ $? -ne 0 ]]; then
			echo "=====> ERROR: Instance deletion failed."
			exit 1
		fi
		echo

    # Show message of confirmation
    echo "========================================="
    echo "==== Removal completed successfully ===="
    echo "========================================="
    echo

  elif [[ "$choice" -eq 4 ]]; then # The user chose to list all the instances

    echo
    echo "===================================================="
    echo "==== Listing all the instances, please wait ... ===="
    echo "===================================================="
    echo 

    # Get the instances and list them 
    instances=$(openstack server list)
    echo "$instances"

    echo "========================================"
    echo "==== Listing completed successfully ===="
    echo "========================================"
    echo

	else # Termination of the script

		echo
		echo "================================"
		echo "==== Exiting the script ... ====" 
		echo "====    See you soon ;)     ===="
		echo "================================"
		exit 1
	fi
done
