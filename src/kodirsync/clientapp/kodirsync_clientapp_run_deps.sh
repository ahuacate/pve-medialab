#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_run_deps.sh
# Description:  Default Kodirsync client SW dependency script for 'kodirsync_clientapp_run.sh'
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

#---- Check & install all client kodirsync SW dependencies

if [[ "$ostype" =~ ^.*(\")?(coreelec|libreelec)(\")?.*$ ]]; then
    # ELEC OS and SW dependencies

    # OS specific dependencies
    if [[ "$ostype" =~ ^.*(\")?coreelec(\")?.*$ ]]; then
        # Check CoreELEC version requirements
        coreelec_ver_min="20.1"  # Minimum required CoreELEC version
        coreelec_ver=$(awk -F '=' '$1 == "VERSION_ID" { gsub(/"/, "", $2); print $2 }' /etc/os-release)

        # Compare CoreELEC versions
        if [[ ! "$(printf '%s\n' "$coreelec_ver_min" "$coreelec_ver" | sort -V | head -n1)" == "$coreelec_ver_min" ]]; then
            # Display a warning message
            echo -e "\e[93m[WARNING]\e[39m \e[97mCoreELEC version is not suitable.\n Minimum required version: $coreelec_ver_min\nBye...\n\e[39m"

            # Log the job failure
            echo -e "#---- JOB START --------------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile
            echo -e "#---- WARNING - CoreELEC VERSION FAIL\nFail Time : $(date)\nCoreELEC version is not suitable.\n Minimum required version: $coreelec_ver_min\n" >> $logfile
            echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile

            exit 1  # Exit the script with a non-zero status code to indicate failure
        fi
    elif [[ "$ostype" =~ ^.*(\")?libreelec(\")?.*$ ]]; then
        # Check LibreELEC versions
        libreelec_ver_min="10.0"  # Minimum required CoreELEC versio
        libreelec_ver=$(awk -F '=' '$1 == "VERSION_ID" { gsub(/"/, "", $2); print $2 }' /etc/os-release)

        # Compare LibreELEC versions
        if [[ ! "$(printf '%s\n' "$libreelec_ver_min" "$libreelec_ver" | sort -V | head -n1)" == "$libreelec_ver_min" ]]; then
            # Display a warning message
            echo -e "\e[93m[WARNING]\e[39m \e[97mLibreELEC version is not suitable.\n Minimum required version: $libreelec_ver_min\nBye...\n\e[39m"

            # Log the job failure
            echo -e "#---- JOB START --------------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile
            echo -e "#---- WARNING - LibreELEC VERSION FAIL\nFail Time : $(date)\nLibreELEC version is not suitable.\n Minimum required version: $libreelec_ver_min\n" >> $logfile
            echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile

            exit 1  # Exit the script with a non-zero status code to indicate failure
        fi
    fi

    # Check for 'EntWare' pkg
    filename=$(find / -type f -name 'installentware')
    if [ -z "$filename" ]; then
        # Display a warning message
        echo -e "\e[93m[WARNING]\e[39m \e[97mEntWare is missing. Run our script 'kodirsync_clientapp_install_elec_entware.sh' and run the Kodirsync again.\nBye...\n\e[39m"

        # Log the job failure
        echo -e "#---- JOB START --------------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile
        echo -e "#---- WARNING - SW DEPENDENCY MISSING\nFail Time : $(date)\nMissing EntWare. Run our script 'kodirsync_clientapp_install_elec_entware.sh' and run Kodirsync again\n" >> $logfile
        echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile

        exit 1  # Exit the script with a non-zero status code to indicate failure
    fi

    # Check SW dependencies for CoreELEC/LibreELEC
    # Required packages
    pkg_LIST=(
        moreutils
        p7zip
    )

    # Function to check if a package is installed
    package_installed() {
        opkg list-installed | grep -q "^$1 - "
    }

    # Check if any required packages are missing
    packages_missing=false
    for pkg in "${pkg_LIST[@]}"; do
        if ! package_installed "$pkg"; then
            packages_missing=true
            break
        fi
    done

    # Perform opkg update and upgrade if any packages are missing
    if [ "$packages_missing" = true ]; then
        echo "Performing opkg update..."
        opkg update
        echo "Performing opkg upgrade..."
        opkg upgrade
    fi

    # Install required packages if missing
    for pkg in "${pkg_LIST[@]}"; do
        if ! package_installed "$pkg"; then
            opkg install "$pkg"
            sleep 0.5
        fi
    done
elif [ "$ostype" = 'termux' ]; then
    # Install Termux-Android dependencies

    source $app_dir/kodirsync_clientapp_install_termux_deps.sh
fi
#-----------------------------------------------------------------------------------------------------------------------