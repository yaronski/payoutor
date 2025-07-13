#!/bin/bash

#    ████████╗██████╗ ███████╗ █████╗ ███████╗██╗   ██╗██████╗ ██╗   ██╗
#    ╚══██╔══╝██╔══██╗██╔════╝██╔══██╗██╔════╝██║   ██║██╔══██╗╚██╗ ██╔╝
#       ██║   ██████╔╝█████╗  ███████║███████╗██║   ██║██████╔╝ ╚████╔╝ 
#       ██║   ██╔══██╗██╔══╝  ██╔══██║╚════██║██║   ██║██╔══██╗  ╚██╔╝  
#       ██║   ██║  ██║███████╗██║  ██║███████║╚██████╔╝██║  ██║   ██║   
#       ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   
#
#    ██████╗  █████╗ ██╗   ██╗ ██████╗ ██╗   ██╗████████╗ ██████╗ ██████╗ 
#    ██╔══██╗██╔══██╗╚██╗ ██╔╝██╔═══██╗██║   ██║╚══██╔══╝██╔═══██╗██╔══██╗
#    ██████╔╝███████║ ╚████╔╝ ██║   ██║██║   ██║   ██║   ██║   ██║██████╔╝
#    ██╔═══╝ ██╔══██║  ╚██╔╝  ██║   ██║██║   ██║   ██║   ██║   ██║██╔══██╗
#    ██║     ██║  ██║   ██║   ╚██████╔╝╚██████╔╝   ██║   ╚██████╔╝██║  ██║
#    ╚═╝     ╚═╝  ╚═╝   ╚═╝    ╚═════╝  ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═╝
#
# Enhanced Token Payout Calculator
# Version: 1.0
# Author: MBTC Team
# Description: Calculates GLMR and MOVR token payouts based on USD amount

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
readonly SCRIPT_NAME=$(basename "$0")
readonly VERSION="2.0"
OUTPUT_FILE="payout_output.txt"
LOG_FILE="payout.log"
CONFIG_FILE="payout_config.json"

# Default values
readonly DEFAULT_GLMR_RATIO=0.6
readonly DEFAULT_MOVR_RATIO=0.4
readonly DEFAULT_BLOCK_AGE_MINUTES=5
readonly DEFAULT_RETRY_ATTEMPTS=3
readonly DEFAULT_TIMEOUT=30

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
USD_AMOUNT=""
GLMR_RATIO=$DEFAULT_GLMR_RATIO
MOVR_RATIO=$DEFAULT_MOVR_RATIO
VERBOSE=false
DRY_RUN=false

# Display ASCII art header
printf "${BLUE}"
cat << 'EOF'
    ████████╗██████╗ ███████╗ █████╗ ███████╗██╗   ██╗██████╗ ██╗   ██╗
    ╚══██╔══╝██╔══██╗██╔════╝██╔══██╗██╔════╝██║   ██║██╔══██╗╚██╗ ██╔╝
       ██║   ██████╔╝█████╗  ███████║███████╗██║   ██║██████╔╝ ╚████╔╝ 
       ██║   ██╔══██╗██╔══╝  ██╔══██║╚════██║██║   ██║██╔══██╗  ╚██╔╝  
       ██║   ██║  ██║███████╗██║  ██║███████║╚██████╔╝██║  ██║   ██║   
       ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   

    ██████╗  █████╗ ██╗   ██╗ ██████╗ ██╗   ██╗████████╗ ██████╗ ██████╗ 
    ██╔══██╗██╔══██╗╚██╗ ██╔╝██╔═══██╗██║   ██║╚══██╔══╝██╔═══██╗██╔══██╗
    ██████╔╝███████║ ╚████╔╝ ██║   ██║██║   ██║   ██║   ██║   ██║██████╔╝
    ██╔═══╝ ██╔══██║  ╚██╔╝  ██║   ██║██║   ██║   ██║   ██║   ██║██╔══██╗
    ██║     ██║  ██║   ██║   ╚██████╔╝╚██████╔╝   ██║   ╚██████╔╝██║  ██║
    ╚═╝     ╚═╝  ╚═╝   ╚═╝    ╚═════╝  ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═╝
EOF
printf "${NC}\n"

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # Always print to stderr for logs
    if [[ "$level" == "ERROR" ]]; then
        echo -e "${RED}[ERROR]${NC} $message" >&2
    elif [[ "$level" == "WARN" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $message" >&2
    elif [[ "$level" == "INFO" ]]; then
        echo -e "${BLUE}[INFO]${NC} $message" >&2
    elif [[ "$level" == "SUCCESS" ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $message" >&2
    fi
}

# Print usage information
usage() {
    cat << EOF
Usage: $SCRIPT_NAME <USD_AMOUNT> [OPTIONS]

Calculate GLMR and MOVR token payouts based on USD amount.

ARGUMENTS:
    USD_AMOUNT    Amount in USD (e.g., 1000.50)

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -d, --dry-run           Show calculations without making API calls
    -c, --config FILE       Use custom configuration file
    -o, --output FILE       Specify output file (default: $OUTPUT_FILE)
    -l, --log FILE          Specify log file (default: $LOG_FILE)
    --glmr-ratio RATIO      GLMR allocation ratio (default: $DEFAULT_GLMR_RATIO)
    --movr-ratio RATIO      MOVR allocation ratio (default: $DEFAULT_MOVR_RATIO)
    --version               Show version information

EXAMPLES:
    $SCRIPT_NAME 1000
    $SCRIPT_NAME 1500.75 --verbose
    $SCRIPT_NAME 2000 --dry-run
    $SCRIPT_NAME 500 --glmr-ratio 0.7 --movr-ratio 0.3

EOF
}

# Print version information
version() {
    echo "$SCRIPT_NAME version $VERSION"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            --glmr-ratio)
                GLMR_RATIO="$2"
                shift 2
                ;;
            --movr-ratio)
                MOVR_RATIO="$2"
                shift 2
                ;;
            --version)
                version
                exit 0
                ;;
            -*)
                log "ERROR" "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [[ -z "$USD_AMOUNT" ]]; then
                    USD_AMOUNT="$1"
                else
                    log "ERROR" "Multiple USD amounts specified"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# Load configuration from file
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log "INFO" "Loading configuration from $CONFIG_FILE"
        if command -v jq &> /dev/null; then
            GLMR_RATIO=$(jq -r '.glmr_ratio // 0.6' "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_GLMR_RATIO")
            MOVR_RATIO=$(jq -r '.movr_ratio // 0.4' "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_MOVR_RATIO")
        else
            log "WARN" "jq not available, using default ratios"
        fi
    fi
}

# Validate configuration
validate_config() {
    if [[ "$GLMR_RATIO" == *","* || "$MOVR_RATIO" == *","* ]]; then
        log "ERROR" "Ratios must use a dot as the decimal separator (e.g., 0.6, not 0,6)"
        exit 1
    fi
    local total_ratio
    total_ratio=$(LC_NUMERIC=C awk "BEGIN {printf \"%.3f\", $GLMR_RATIO + $MOVR_RATIO}")
    if [[ $(echo "$total_ratio != 1.000" | bc -l 2>/dev/null || echo "1") == "1" ]]; then
        log "WARN" "Ratios don't sum to 1.000 (GLMR: $GLMR_RATIO, MOVR: $MOVR_RATIO, Total: $total_ratio)"
    fi

    if [[ $(echo "$GLMR_RATIO < 0" | bc -l 2>/dev/null || echo "1") == "1" ]] || \
       [[ $(echo "$MOVR_RATIO < 0" | bc -l 2>/dev/null || echo "1") == "1" ]]; then
        log "ERROR" "Ratios must be positive"
        exit 1
    fi
}

# Check if dependencies are installed
check_dependencies() {
    local missing_deps=()

    for cmd in curl jq awk bc; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Missing dependencies: ${missing_deps[*]}"
        echo "Please install missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                curl)
                    echo "  - curl: brew install curl"
                    ;;
                jq)
                    echo "  - jq: brew install jq"
                    ;;
                awk)
                    echo "  - awk: Usually pre-installed on macOS"
                    ;;
                bc)
                    echo "  - bc: brew install bc"
                    ;;
            esac
        done
        exit 1
    fi

    log "INFO" "All dependencies are available"
}

# Validate USD amount
validate_usd_amount() {
    if [[ -z "$USD_AMOUNT" ]]; then
        log "ERROR" "USD amount is required"
        usage
        exit 1
    fi

    # Check if it's a valid number
    if ! echo "$USD_AMOUNT" | grep -Eq '^[0-9]+(\.[0-9]{1,2})?$'; then
        log "ERROR" "USD amount must be a number with up to two decimal places (e.g., 1000 or 1000.50)"
        exit 1
    fi

    # Check if it's positive
    if [[ $(echo "$USD_AMOUNT <= 0" | bc -l) == "1" ]]; then
        log "ERROR" "USD amount must be positive"
        exit 1
    fi

    log "INFO" "USD amount validated: $USD_AMOUNT"
}

# Get recent block number via HTML scraping
get_recent_block() {
    local network=$1
    local timeout=${2:-$DEFAULT_TIMEOUT}

    log "INFO" "Fetching recent block for $network via HTML scraping"

    local html_url="https://${network}.subscan.io/block"
    local block_num_html
    block_num_html=$(curl -s --max-time "$timeout" "$html_url" | grep -oE 'block/[0-9]+' | head -1 | grep -oE '[0-9]+')
    
    if [[ -n "$block_num_html" ]]; then
        # Subtract 200 blocks to get a much older block for price stability and EMA30 availability
        local adjusted_block
        adjusted_block=$((block_num_html - 200))
        log "SUCCESS" "Got latest block $block_num_html for $network, using adjusted block $adjusted_block for price calculation"
        echo "$adjusted_block"
        return 0
    else
        log "ERROR" "Failed to fetch block number for $network via HTML scraping"
        return 1
    fi
}

# Get token EMA30 price with retry logic
get_token_price() {
    local network=$1
    local token=$2
    local block=$3
    local attempts=${4:-$DEFAULT_RETRY_ATTEMPTS}
    local timeout=${5:-$DEFAULT_TIMEOUT}

    log "INFO" "Fetching $token EMA30 price for block $block on $network"

    for ((i=1; i<=attempts; i++)); do
    local url="https://${network}.subscan.io/tools/price_converter?value=1&type=block&from=${token}&to=USD&time=${block}"
        if [[ "$VERBOSE" == "true" ]]; then
            log "INFO" "Attempt $i: Fetching from $url"
        fi

        # Extract EMA30 price using grep/tail method
        local ema30
        ema30=$(curl -s --max-time "$timeout" "$url" \
            | grep -o '"ema30_average":"[0-9.]*"' \
            | tail -1 \
            | grep -o '[0-9.]*' \
            | tail -1)

        if [[ "$VERBOSE" == "true" ]]; then
            log "INFO" "Raw EMA30 extraction: $ema30"
        fi

        # Debug: Always log the raw value and validation result
        log "INFO" "Raw EMA30 value: '$ema30'"
        log "INFO" "Validation result: $([[ "$ema30" =~ ^[0-9]+(\.[0-9]+)?$ ]] && echo "VALID" || echo "INVALID")"

        # Validate price is a decimal
        if [[ "$ema30" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            local formatted_price
            formatted_price=$(LC_NUMERIC=C echo "scale=6; $ema30" | bc)
            # Ensure leading zero for values less than 1
            if [[ "$formatted_price" =~ ^\.[0-9]+$ ]]; then
                formatted_price="0$formatted_price"
            fi
            log "SUCCESS" "Got $token EMA30 price: $formatted_price USD"
            echo "$formatted_price"
            return 0
        else
            log "WARN" "EMA30 price not found for $token, trying again if attempts remain."
        fi

        if [[ $i -lt $attempts ]]; then
            log "WARN" "Attempt $i failed for $token EMA30 price, retrying in 2 seconds..."
            sleep 2
        fi
    done

    log "ERROR" "Failed to fetch EMA30 price for $token at block $block after $attempts attempts"
    return 1
}

# Calculate token amounts
calculate_token_amounts() {
    local glmr_usd
    glmr_usd=$(LC_NUMERIC=C echo "$USD_AMOUNT * $GLMR_RATIO" | bc -l)
    local movr_usd
    movr_usd=$(LC_NUMERIC=C echo "$USD_AMOUNT * $MOVR_RATIO" | bc -l)

    log "INFO" "Calculated USD splits: GLMR=$glmr_usd, MOVR=$movr_usd"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Using mock prices for calculation"
        local mock_glmr_price=0.25
        local mock_movr_price=0.15
        local glmr_amount
        glmr_amount=$(LC_NUMERIC=C echo "$glmr_usd / $mock_glmr_price" | bc -l)
        local movr_amount
        movr_amount=$(LC_NUMERIC=C echo "$movr_usd / $mock_movr_price" | bc -l)

        echo "$glmr_amount $movr_amount $mock_glmr_price $mock_movr_price mock_block mock_block"
        return 0
    fi

    # Get recent blocks
    local moonbeam_block
    local moonriver_block

    log "INFO" "Fetching Moonbeam block..."
    moonbeam_block=$(get_recent_block "moonbeam")
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to get Moonbeam block"
        exit 1
    fi

    log "INFO" "Fetching Moonriver block..."
    moonriver_block=$(get_recent_block "moonriver")
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to get Moonriver block"
        exit 1
    fi

    # Get token prices
    local glmr_price
    local movr_price

    log "INFO" "Fetching GLMR price for block $moonbeam_block..."
    glmr_price=$(get_token_price "moonbeam" "GLMR" "$moonbeam_block")
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to get GLMR price"
        exit 1
    fi

    log "INFO" "Fetching MOVR price for block $moonriver_block..."
    movr_price=$(get_token_price "moonriver" "MOVR" "$moonriver_block")
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to get MOVR price"
        exit 1
    fi

    # Calculate token amounts with error handling
    local glmr_amount
    glmr_amount=$(LC_NUMERIC=C echo "$glmr_usd / $glmr_price" | bc -l 2>/dev/null || echo "0")
    local movr_amount
    movr_amount=$(LC_NUMERIC=C echo "$movr_usd / $movr_price" | bc -l 2>/dev/null || echo "0")

    # Validate calculations
    if [[ "$glmr_amount" == "0" || "$movr_amount" == "0" ]]; then
        # Format prices for error logging to avoid locale issues
        local glmr_price_log
        glmr_price_log=$(LC_NUMERIC=C echo "scale=6; $glmr_price" | bc)
        local movr_price_log
        movr_price_log=$(LC_NUMERIC=C echo "scale=6; $movr_price" | bc)
        log "ERROR" "Token amount calculation failed. GLMR: $glmr_amount, MOVR: $movr_amount"
        log "ERROR" "USD splits: GLMR=$glmr_usd, MOVR=$movr_usd"
        log "ERROR" "Prices: GLMR=$glmr_price_log, MOVR=$movr_price_log"
        exit 1
    fi

    echo "$glmr_amount $movr_amount $glmr_price $movr_price $moonbeam_block $moonriver_block"
}

# Main function
main() {
    log "INFO" "Starting $SCRIPT_NAME v$VERSION"

    # Parse arguments
    parse_args "$@"

    # Load configuration
    load_config

    # Validate configuration
    validate_config

# Check dependencies
check_dependencies

    # Validate USD amount
    validate_usd_amount

    log "INFO" "Processing USD amount: $USD_AMOUNT"
    log "INFO" "Using ratios: GLMR=$GLMR_RATIO, MOVR=$MOVR_RATIO"

    # Calculate token amounts
    local result
    result=$(calculate_token_amounts) || exit 1

    # Parse results
    local glmr_amount
    glmr_amount=$(echo "$result" | awk '{print $1}')
    local movr_amount
    movr_amount=$(echo "$result" | awk '{print $2}')
    local glmr_price
    glmr_price=$(echo "$result" | awk '{print $3}')
    local movr_price
    movr_price=$(echo "$result" | awk '{print $4}')
    local moonbeam_block
    moonbeam_block=$(echo "$result" | awk '{print $5}')
    local moonriver_block
    moonriver_block=$(echo "$result" | awk '{print $6}')

    # Validate parsed values
    if [[ -z "$glmr_amount" || -z "$movr_amount" || -z "$glmr_price" || -z "$movr_price" ]]; then
        log "ERROR" "Failed to parse calculation results"
    exit 1
fi

    # Calculate USD shares with explicit dot decimal separator and error handling
    local glmr_usd_share
    glmr_usd_share=$(LC_NUMERIC=C echo "scale=2; $USD_AMOUNT * $GLMR_RATIO" | bc 2>/dev/null || echo "0.00")
    local movr_usd_share
    movr_usd_share=$(LC_NUMERIC=C echo "scale=2; $USD_AMOUNT * $MOVR_RATIO" | bc 2>/dev/null || echo "0.00")

    # Format amounts with explicit dot decimal separator and error handling
    local glmr_amount_formatted
    glmr_amount_formatted=$(LC_NUMERIC=C echo "scale=2; $glmr_amount" | bc | sed 's/^0*//' | sed 's/^\./0./')
    local movr_amount_formatted
    movr_amount_formatted=$(LC_NUMERIC=C echo "scale=2; $movr_amount" | bc | sed 's/^0*//' | sed 's/^\./0./')
    local glmr_price_formatted
    glmr_price_formatted=$(LC_NUMERIC=C echo "scale=6; $glmr_price" | bc)
    local movr_price_formatted
    movr_price_formatted=$(LC_NUMERIC=C echo "scale=6; $movr_price" | bc)

    # Output results
    echo
    echo "=== PAYOUT CALCULATION RESULTS ==="
    echo "USD Amount: $USD_AMOUNT"
    echo "GLMR Allocation: $glmr_usd_share USD"
    echo "MOVR Allocation: $movr_usd_share USD"
    echo "GLMR Price: $glmr_price_formatted USD"
    echo "MOVR Price: $movr_price_formatted USD"
    echo "GLMR Amount: $glmr_amount_formatted"
    echo "MOVR Amount: $movr_amount_formatted"
    echo "Moonbeam Block: $moonbeam_block"
    echo "Moonriver Block: $moonriver_block"
    echo "=================================="
    echo

    # Generate simple output format
    cat << EOF
Moonbeam $(LC_NUMERIC=C echo "$GLMR_RATIO * 100" | bc -l | LC_NUMERIC=C xargs printf "%.0f")% share in USD

Moonbeam 30d EMA GLMR price block: $moonbeam_block
https://moonbeam.subscan.io/tools/price_converter?value=1&type=block&from=GLMR&to=USD&time=$moonbeam_block

Moonbeam $(LC_NUMERIC=C echo "$GLMR_RATIO * 100" | bc -l | LC_NUMERIC=C xargs printf "%.0f")% share in GLMR: $glmr_amount_formatted
https://moonbeam.subscan.io/tools/price_converter?value=$glmr_amount_formatted&type=block&from=GLMR&to=USD&time=$moonbeam_block

Moonriver $(LC_NUMERIC=C echo "$MOVR_RATIO * 100" | bc -l | LC_NUMERIC=C xargs printf "%.0f")% share in USD

Moonriver 30d EMA MOVR price block: $moonriver_block
https://moonriver.subscan.io/tools/price_converter?value=1&type=block&from=MOVR&to=USD&time=$moonriver_block

Moonriver $(LC_NUMERIC=C echo "$MOVR_RATIO * 100" | bc -l | LC_NUMERIC=C xargs printf "%.0f")% share in MOVR: $movr_amount_formatted
https://moonriver.subscan.io/tools/price_converter?value=$movr_amount_formatted&type=block&from=MOVR&to=USD&time=$moonriver_block
EOF

    # Save to file
    {
        echo "=== PAYOUT CALCULATION RESULTS ==="
        echo "USD Amount: $USD_AMOUNT"
        echo "GLMR Allocation: $glmr_usd_share USD"
        echo "MOVR Allocation: $movr_usd_share USD"
        echo "GLMR Price: $glmr_price_formatted USD"
        echo "MOVR Price: $movr_price_formatted USD"
        echo "GLMR Amount: $glmr_amount_formatted"
        echo "MOVR Amount: $movr_amount_formatted"
        echo "Moonbeam Block: $moonbeam_block"
        echo "Moonriver Block: $moonriver_block"
        echo "=================================="
        echo
        echo "Moonbeam $(LC_NUMERIC=C echo "$GLMR_RATIO * 100" | bc -l | LC_NUMERIC=C xargs printf "%.0f")% share in USD"
        echo
        echo "Moonbeam 30d EMA GLMR price block: $moonbeam_block"
        echo "https://moonbeam.subscan.io/tools/price_converter?value=1&type=block&from=GLMR&to=USD&time=$moonbeam_block"
        echo
        echo "Moonbeam $(LC_NUMERIC=C echo "$GLMR_RATIO * 100" | bc -l | LC_NUMERIC=C xargs printf "%.0f")% share in GLMR: $glmr_amount_formatted"
        echo "https://moonbeam.subscan.io/tools/price_converter?value=$glmr_amount_formatted&type=block&from=GLMR&to=USD&time=$moonbeam_block"
        echo
        echo "Moonriver $(LC_NUMERIC=C echo "$MOVR_RATIO * 100" | bc -l | LC_NUMERIC=C xargs printf "%.0f")% share in USD"
        echo
        echo "Moonriver 30d EMA MOVR price block: $moonriver_block"
        echo "https://moonriver.subscan.io/tools/price_converter?value=1&type=block&from=MOVR&to=USD&time=$moonriver_block"
        echo
        echo "Moonriver $(LC_NUMERIC=C echo "$MOVR_RATIO * 100" | bc -l | LC_NUMERIC=C xargs printf "%.0f")% share in MOVR: $movr_amount_formatted"
        echo "https://moonriver.subscan.io/tools/price_converter?value=$movr_amount_formatted&type=block&from=MOVR&to=USD&time=$moonriver_block"
    } > "$OUTPUT_FILE"
    
    log "SUCCESS" "Output saved to $OUTPUT_FILE"
    log "INFO" "Script completed successfully"
}

# Run main function with all arguments
main "$@"