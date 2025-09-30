#!/bin/bash

################################################################################
# Google Drive + Netskope Certificate Bundle Configuration
# Version: 1.5
#
# This script configures Google Drive for Desktop to trust SSL certificates
# when behind Netskope SSL decryption. It downloads and bundles together
# Netskope's CA certificates and Mozilla's trusted root CA bundle, then
# configures Google Drive to trust the new certificate bundle.
#
# Requirements:
#   - macOS
#   - Google Drive for Desktop installed
#   - curl
#   - sudo privileges
#
# Usage:
#   sudo ./configure-google-drive-netskope.sh
#
# Author: Peter Hayes
# License: MIT
#
# Disclaimer:
#   This project is not affiliated with or supported by Netskope.
#   It may be incomplete, outdated, or inaccurate.
#   Use at your own risk.
################################################################################

set -euo pipefail

################################################################################
# CONFIGURATION - Edit these values to reflect your Netskope tenant details
################################################################################

# Your Netskope tenant FQDN
readonly TENANT_NAME="example.goskope.com"

# Found in: Settings > Security Cloud Platform > MDM Distribution > Organization ID
readonly ORG_KEY="abc123"

# Allow cURL to skip SSL/TLS certificate validation
# Default: true (cURL may not trust the OS certificate store)
# Refer to documentation for details
readonly ALLOW_INSECURE_SSL="true"   # Options: "true" or "false"

# Local Netskope + Mozilla certificate bundle filename
readonly CERT_FILENAME="netskope-cert-bundle.pem"

# Logging options:
#   "cli"   = Output to CLI
#   "file"  = Write to a log file in the same directory as the certificate
#   "both"  = Output both to CLI and a log file
readonly LOG_MODE="both"

################################################################################
# Derived Paths
################################################################################

# Detect actual user's home directory (works correctly with sudo)
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME=$(eval echo "~${SUDO_USER}")
else
    USER_HOME="${HOME}"
fi

# Paths for certificate storage
readonly CERT_DIR="${USER_HOME}/Netskope Certificates"
readonly CERT_PATH="${CERT_DIR}/${CERT_FILENAME}"
readonly TEMP_CERT_PATH="${CERT_DIR}/${CERT_FILENAME}.tmp"

# Path for optional log file
readonly LOG_FILE="${CERT_DIR}/configure-google-drive-netskope.log"

# Google Drive for Desktop settings plist
readonly GDRIVE_PLIST="/Library/Preferences/com.google.drivefs.settings"

# Set cURL options based on SSL/TLS configuration
if [[ "$ALLOW_INSECURE_SSL" == "true" ]]; then
    readonly CURL_OPTS="-fsSLk"
else
    readonly CURL_OPTS="-fsSL"
fi

################################################################################
# Logging Helpers
################################################################################

# Ensure log directory exists if using logging mode is set to file/both
if [[ "$LOG_MODE" == "file" || "$LOG_MODE" == "both" ]]; then
    mkdir -p "$CERT_DIR"
    touch "$LOG_FILE"
fi

log_output() {
    local level="$1"
    local msg="$2"
    local formatted="[$level] $msg"

    case "$LOG_MODE" in
        cli)
            if [[ "$level" == "ERROR" ]]; then
                echo -e "$formatted" >&2
            else
                echo -e "$formatted"
            fi
            ;;
        file)
            echo -e "$formatted" >> "$LOG_FILE"
            ;;
        both)
            if [[ "$level" == "ERROR" ]]; then
                echo -e "$formatted" >&2
            else
                echo -e "$formatted"
            fi
            echo -e "$formatted" >> "$LOG_FILE"
            ;;
    esac
}

log_info()    { log_output "INFO" "$*"; }
log_error()   { log_output "ERROR" "$*"; }
log_success() { log_output "SUCCESS" "$*"; }

################################################################################
# Requirement Checks
################################################################################

check_requirements() {
    log_info "Checking requirements..."

    # Ensure the required commands are available
    for cmd in curl shasum defaults; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done

    # Ensure Google Drive for Desktop is installed
    if [ ! -d "/Applications/Google Drive.app" ]; then
        log_error "Google Drive for Desktop not installed."
        exit 1
    fi

    log_success "All requirements met."
}

################################################################################
# Configuration Validation
################################################################################

validate_config() {
    if [[ "$TENANT_NAME" == "example.goskope.com" ]] || \
       [[ "$ORG_KEY" == "abc123" ]]; then
        log_error "Default configuration values found!"
        log_error "Please edit the CONFIGURATION section at the top of this script."
        exit 1
    fi
}

################################################################################
# Certificate Bundle Handling
################################################################################

# Build a new certificate bundle and store in a temporary file

build_cert_bundle_temp() {
    mkdir -p "$CERT_DIR"
    rm -f "$TEMP_CERT_PATH"

    log_info "Creating temporary certificate bundle:\n$TEMP_CERT_PATH"

    # Download Netskope root CA certificate
    if ! curl $CURL_OPTS "https://addon-${TENANT_NAME}/config/ca/cert?orgkey=${ORG_KEY}" \
        -o "$TEMP_CERT_PATH"; then
        log_error "Failed to download Netskope root CA certificate."
        exit 1
    fi

    # Download Netskope intermediate CA certificate
    if ! curl $CURL_OPTS "https://addon-${TENANT_NAME}/config/org/cert?orgkey=${ORG_KEY}" \
        >> "$TEMP_CERT_PATH"; then
        log_error "Failed to download Netskope intermediate CA certificate."
        exit 1
    fi

    # Download Mozilla's trusted root CA bundle
    if ! curl $CURL_OPTS "https://curl.se/ca/cacert.pem" >> "$TEMP_CERT_PATH"; then
        log_error "Failed to download Mozilla CA bundle."
        exit 1
    fi
}

# Compute SHA-256 hash of a file
get_file_hash() {
    local file="$1"
    shasum -a 256 "$file" | awk '{print $1}'
}

################################################################################
# Google Drive Configuration
################################################################################

configure_google_drive() {
    local new_hash current_hash current_cert_path
    local needs_update=false

    # Build new certificate bundle
    build_cert_bundle_temp
    new_hash=$(get_file_hash "$TEMP_CERT_PATH")

    # Get currently configured bundle path
    current_cert_path=$(defaults read "$GDRIVE_PLIST" TrustedRootCertsFile 2>/dev/null || echo "")

	# Compare the hash of the temporary bundle with the existing one (if present)
	# Indicate replacement if the file contents differ
    if [ -n "$current_cert_path" ] && [ -f "$current_cert_path" ]; then
        current_hash=$(get_file_hash "$current_cert_path")
        log_info "Current bundle hash:\n$current_hash"
        log_info "New bundle hash:\n$new_hash"

        if [ "$current_hash" != "$new_hash" ]; then
            log_info "Temporary bundle differs from the existing bundle."
            needs_update=true
        else
            log_info "Temporary bundle is identical to the existing bundle."
        fi
    else
        log_info "No valid certificate bundle and/or folder location configured."
        needs_update=true
    fi

	# Update certificate bundle and restart Google Drive
    if [ "$needs_update" = true ]; then
        log_info "Replacing old bundle with new one..."
        if [ -n "${current_hash:-}" ]; then
            log_info "Old bundle hash:\n$current_hash"
        else
            log_info "Old bundle: none"
        fi
        log_info "New bundle hash:\n$new_hash"

        mv "$TEMP_CERT_PATH" "$CERT_PATH"
        log_success "Certificate bundle is up to date."
        defaults write "$GDRIVE_PLIST" TrustedRootCertsFile "$CERT_PATH"

        log_success "Google Drive configured to trust:\n$CERT_PATH"

        # Restart Google Drive
        log_info "Restarting Google Drive to apply changes"
        killall -9 "Google Drive" "Google Drive Helper" 2>/dev/null || true
        sleep 5
        if ! open -a "Google Drive"; then
            log_error "Failed to restart Google Drive. Please open the app manually."
        else
            log_success "Google Drive restarted successfully."
        fi
    else
        log_success "Certificate bundle is up to date."
        rm -f "$TEMP_CERT_PATH"
    fi
}

################################################################################
# Display Current Configuration
################################################################################

display_current_config() {
    local current_value
    current_value=$(defaults read "$GDRIVE_PLIST" TrustedRootCertsFile 2>/dev/null || echo "TrustedRootCertsFile not configured/readable")

    log_info "Current TrustedRootCertsFile Configuration:\n${current_value}"

}

################################################################################
# Main
################################################################################

main() {
    local start_time end_time
    start_time=$(date +"%Y-%m-%d %H:%M:%S")

    log_info "Script started at $start_time"

    log_info "Starting Google Drive + Netskope SSL Certificate Trust configuration..."
    check_requirements
    validate_config
    configure_google_drive
    display_current_config
    log_success "Configuration complete!"

    if [[ "$LOG_MODE" == "file" || "$LOG_MODE" == "both" ]]; then
        log_info "Log written to: $LOG_FILE"
    fi

    end_time=$(date +"%Y-%m-%d %H:%M:%S")
    log_info "Script ended at $end_time"
}

main "$@"