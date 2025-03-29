Overview

This batch script is designed to perform system maintenance tasks on Windows, including scanning and fixing system errors, checking drive health, running CHKDSK, performing disk cleanup, and defragmentation. It provides users with multiple options to run scans, apply fixes, or execute full maintenance routines.

Features

✅ Complete Maintenance (Scan & Fix)

🔍 Scan-Only Mode (No fixes applied)

🔧 Fix-Only Mode (Applies fixes without scanning)

📊 Event System Scanner

🛠 Memory Diagnostics

⚙️ Advanced Maintenance Options (to be defined)

🎛 User-friendly menu interface

Prerequisites

🛑 Administrator Privileges Required

💻 Compatible with Windows 10 & 11 (Requires SFC, DISM, CHKDSK, etc.)

Installation & Usage

1️⃣ Download & Run the Script

Clone or download the repository, then run the script as Administrator:

Right-click > Run as administrator

Or execute from the command prompt:

cmd /c "path\to\script.bat"

2️⃣ Select an option from the menu:

Use the corresponding number (1-8) to choose an action.

Menu Options

Run Full Maintenance (Recommended)

Scans system files, repairs errors, checks disk health, and optimizes performance.

Scan System for Errors Only

Runs scans without applying any fixes.

Run Event System Scanner (To be implemented)

Checks system logs for potential issues.

Diagnose Memory Issues

Runs Windows Memory Diagnostic tool.

Advanced Maintenance Options (To be implemented)

Additional expert-level maintenance features.

Scan Only (All scans, no fixes)

Similar to option 2 but includes more comprehensive scans.

Fix All (All fixes, no scan)

Applies all available fixes without running preliminary scans.

Exit

Closes the script.

⚠️ Important Notes

Some maintenance tasks may take time depending on system health and disk size.

Running CHKDSK may require a system restart.

Ensure all work is saved before running intensive maintenance tasks.

📜 License

This script is provided "as is" without any warranty. Use it at your own risk. The author is not responsible for any system issues arising from running this script.

🔄 Compatibility

This script is designed for Windows 10 & 11. Further testing is planned for other versions.

🚀 Contributions

Pull requests & feature suggestions are welcome! Feel free to fork and improve the script.

📌 Author: Jacob Cooper
