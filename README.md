# Token Payout Calculator for Moonbeam & Moonriver

## Overview

`token_payout.sh` is a Bash script designed to automate the calculation of GLMR and MOVR token Treasury payouts based on a specified USD amount. It fetches recent block numbers and the 30-day EMA (Exponential Moving Average) price for each token from Subscan, ensuring accurate payout calculations for the Moonbeam and Moonriver networks.

## Features
- **Automated payout calculation** for GLMR and MOVR based on a USD input
- **Fetches recent block numbers** for both networks (with offset for price stability)
- **Extracts 30d EMA price** for the exact block from Subscan's price converter tool
- **Robust error handling** and logging
- **Customizable payout ratios** (GLMR/MOVR)
- **Configurable output and log files**
- **Professional, clear output** (terminal and file)

## Requirements
- Bash (tested on macOS, should work on Linux)
- `curl` (for HTTP requests)
- `awk`, `bc`, `grep`, `sed` (standard Unix tools)
- (Optional) `jq` (for config file parsing)

Install missing dependencies on macOS with Homebrew:
```sh
brew install curl jq bc
```

## Installation
1. Place `token_payout.sh` in your working directory.
2. Make it executable:
   ```sh
   chmod +x token_payout.sh
   ```
3. (Optional) Create a `payout_config.json` for custom ratios (see below).

## Usage
```sh
./token_payout.sh <USD_AMOUNT> [OPTIONS]
```

### Arguments
- `<USD_AMOUNT>`: The total payout amount in USD (e.g., `1000`, `1500.50`)

### Options
- `-h, --help`           Show help message
- `-v, --verbose`        Enable verbose output (debug/logging)
- `-c, --config FILE`    Use a custom configuration file (default: payout_config.json)
- `-o, --output FILE`    Specify output file (default: payout_output.txt)
- `-l, --log FILE`       Specify log file (default: payout.log)
- `--glmr-ratio RATIO`   Set GLMR allocation ratio (default: 0.6)
- `--movr-ratio RATIO`   Set MOVR allocation ratio (default: 0.4)
- `--version`            Show version information

### Examples
```sh
# Basic payout calculation for $1000
./token_payout.sh 1000

# Custom ratios and verbose logging
./token_payout.sh 2000 --glmr-ratio 0.7 --movr-ratio 0.3 --verbose

# Use a custom config file and output file
./token_payout.sh 1500 -c my_config.json -o my_output.txt
```

## Configuration
You can use a JSON config file (default: `payout_config.json`) to set custom payout ratios:
```json
{
  "glmr_ratio": 0.65,
  "movr_ratio": 0.35
}
```

## Output
- Results are printed to the terminal and saved to the output file (default: `payout_output.txt`).
- Log messages are saved to the log file (default: `payout.log`).

## Troubleshooting
- **Missing dependencies:** The script will alert you if required tools are missing.
- **API/network errors:** If Subscan is unreachable or the price is unavailable for a block, the script will retry and log errors.
- **Locale issues:** The script forces `LC_NUMERIC=C` for all calculations to avoid decimal/comma confusion.
- **No EMA30 price for block:** The script uses a recent block (latest - 200) to maximize the chance of a valid EMA30 price. If you need a different block, adjust the offset in the script.

## FAQ
**Q: How does the script get the EMA30 price for a block?**  
A: It scrapes the Subscan price converter tool for the exact block and extracts the last available 30d EMA price shown on the page, matching what you see in the UI.

**Q: Can I use this for other tokens or networks?**  
A: The script is tailored for GLMR (Moonbeam) and MOVR (Moonriver) but can be adapted for similar Subscan-supported networks.

**Q: How do I change the payout ratios?**  
A: Use the `--glmr-ratio` and `--movr-ratio` options, or set them in a config file.

**Q: What if the script fails to get a price?**  
A: It will retry several times and log errors. If the block is too recent, try a slightly older block.

**Q: How do I get the 30d EMA for an exact block?**  
A: The script uses the block number in the Subscan tool and extracts the EMA30 price shown for that block, just as you would do manually.

---

For questions or improvements, contact the MBTC Team or open an issue in the project repository. 