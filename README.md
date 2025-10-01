# configure-google-drive-netskope
A Bash script that configures **Google Drive for Desktop on macOS** to trust SSL certificates when behind **Netskope SSL Decryption**. 

Unlike most apps on macOS, Google Drive maintains its own certificate store and doesn't trust the system store. This script bundles Netskope’s CA certificates together with Mozilla’s trusted root CA bundle, ensuring Google Drive continues to function correctly whether Netskope SSL Decryption is enabled or disabled. It then updates Google Drive’s [TrustedRootCertsFile](https://support.google.com/a/answer/7644837?hl=en) setting and restarts the app to apply changes.

## Features
- Validates required tools and dependencies  
- Downloads Netskope root and intermediate CA certificates, plus Mozilla’s CA bundle  
- Detects and replaces stale certificate bundles  
- Updates Google Drive’s `TrustedRootCertsFile` setting to use the new bundle  
- Supports configurable logging (CLI, file, or both)  
- Cleanly restarts Google Drive to apply changes

## Requirements
- macOS
- Google Drive for Desktop
- `curl`
- `shasum`
- `defaults`
- `sudo` privileges

## Usage
1. Clone or download this repository.
2. `cd google-drive-netskope-cert-bundle`
3. Edit the script to match your configuration.
4. `chmod +x configure-google-drive-netskope.sh`
5. `sudo ./configure-google-drive-netskope.sh`
6. If macOS quarantines the file, run:
   - `xattr -d com.apple.quarantine ./configure-google-drive-netskope.sh`

## Configuration
Edit the **CONFIGURATION** section at the top of the script:

- **TENANT_NAME** — your Netskope tenant FQDN (e.g., example.goskope.com)
- **ORG_KEY** — found within the Netskope Administrator Portal under Settings > Security Cloud Platform > MDM Distribution > Organization ID
- **ALLOW_INSECURE_SSL** — allow cURL to skip SSL/TLS validation (`true`/`false`)  
  - Default: `true` (cURL may not trust Netskope’s certificate by default.)
  - If set to `false`, you can either configure cURL to trust the Netskope CA, configure cURL as a [certificate pinned application](https://docs.netskope.com/en/certificate-pinned-applications/) in Netskope, or bypass the domain `curl.se` from Netskope SSL Decryption.  
- **CERT_FILENAME** — certificate bundle filename
- **LOG_MODE** — choose `cli`, `file`, or `both`

## Future Updates
A comparable script for Google Drive for Desktop on Windows is in development.

## License
Licensed under MIT — free to use, modify, and share, with no warranty.

## Disclaimer
This project is **not affiliated with or supported by Netskope**. It may be incomplete, outdated, or inaccurate. Use at your own risk. 
