# configure-google-drive-netskope
Configures Google Drive for Desktop on macOS to trust Netskope SSL decryption by bundling Netskope and Mozilla CA certificates, updating Google Drive’s settings, and restarting the app.

## Features
- Validates required tools and dependencies  
- Downloads Netskope root and intermediate CA certificates, plus Mozilla’s CA bundle  
- Detects and replaces stale certificate bundles  
- Updates Google Drive’s 'TrustedRootCertsFile' setting to use the new bundle  
- Supports configurable logging (CLI, file, or both)  
- Cleanly restarts Google Drive to apply changes

## Requirements
- macOS
- Google Drive for Desktop
- 'curl'
- 'shasum'
- 'defaults'
- 'sudo' privileges

## License
Licensed under MIT — free to use, modify, and share, with no warranty.

## Disclaimer
This project is **not affiliated with or supported by Netskope**. It may be incomplete, outdated, or inaccurate. Use at your own risk. 
