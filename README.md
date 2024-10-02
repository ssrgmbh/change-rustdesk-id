# RustDesk Configuration Update Script

This PowerShell script automates the process of updating RustDesk configurations and securely storing the information in Bitwarden. It provides a user-friendly interface for changing RustDesk IDs and passwords, with options for customization and secure storage.

## Features

- Update RustDesk ID with options for:
  - Using the system hostname
  - Generating a random 9-digit number
  - Entering a custom value
- Generate a new random password for RustDesk
- Securely store RustDesk ID and password in Bitwarden
- Automatic installation of Bitwarden CLI if not present
- Support for custom Bitwarden server URLs

## Prerequisites

- Windows operating system
- PowerShell 5.1 or later
- RustDesk installed on the system
- Bitwarden account (optional, for secure storage)
- Internet connection (for Bitwarden CLI installation and synchronization)

## Installation

1. Clone this repository or download the script file:
   ```
   git clone https://github.com/yourusername/rustdesk-config-update.git
   ```
   or download `rustdesk-config-update.ps1` directly.

2. Ensure PowerShell execution policy allows running scripts. You may need to run:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## Usage

1. Open PowerShell as an administrator.

2. Navigate to the directory containing the script:
   ```powershell
   cd path\to\script\directory
   ```

3. Run the script:
   ```powershell
   .\rustdesk-config-update.ps1
   ```

4. Follow the on-screen prompts to:
   - Choose a new RustDesk ID
   - Confirm the updates
   - Optionally save the information to Bitwarden

## Configuration

The script doesn't require any pre-configuration. All necessary inputs are prompted during execution.

## Security Considerations

- The script generates a random 16-character password for RustDesk.
- Bitwarden is used for secure storage of RustDesk credentials.
- The Bitwarden CLI session is cleared after use.
- No sensitive information is stored within the script itself.

## Contributing

Contributions to improve the script are welcome. Please follow these steps:

1. Fork the repository
2. Create a new branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` file for more information.

## Acknowledgements

- [RustDesk](https://rustdesk.com/)
- [Bitwarden](https://bitwarden.com/)
- [PowerShell](https://docs.microsoft.com/en-us/powershell/)

## Support

For support, please open an issue in the GitHub repository.
