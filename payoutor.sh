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
export LC_NUMERIC=C  # Force US locale for number formatting

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
RECIPIENT_ADDRESS=""
COUNCIL_THRESHOLD=3
COUNCIL_LENGTH_BOUND=10000
MOONBEAM_WS_ENDPOINT="wss://wss.api.moonbeam.network"
MOONRIVER_WS_ENDPOINT="wss://wss.api.moonriver.moonbeam.network"
JSON_OUTPUT=false
MARKDOWN_OUTPUT=false
PROXY_ENABLED=false
PROXY_ADDRESS=""

# Display ASCII art header
echo
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
Usage: $SCRIPT_NAME <USD_AMOUNT> [RECIPIENT_ADDRESS] [OPTIONS]

Calculate GLMR and MOVR token payouts based on USD amount.
Optionally generate extrinsic call data for treasury proposals.

ARGUMENTS:
    USD_AMOUNT         Amount in USD (e.g., 1000.50)
    RECIPIENT_ADDRESS  Optional: Ethereum-style address for treasury proposal

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -d, --dry-run           Show calculations without making API calls
    -c, --config FILE       Use custom configuration file
    -o, --output FILE       Specify output file (default: $OUTPUT_FILE)
    -l, --log FILE          Specify log file (default: $LOG_FILE)
    --glmr-ratio RATIO      GLMR allocation ratio (default: $DEFAULT_GLMR_RATIO)
    --movr-ratio RATIO      MOVR allocation ratio (default: $DEFAULT_MOVR_RATIO)
            --council-threshold N   Council threshold (default: 3)
            --council-length-bound N Length bound (default: 10000)
            --moonbeam-ws URL       Moonbeam WebSocket endpoint
            --moonriver-ws URL      Moonriver WebSocket endpoint
    --json                  Output results in JSON format
    --markdown|--md-table  Output results in Markdown table format
    --proxy                Output proxy call data in addition to normal call data
    --proxy-address ADDR   Specify proxy address (overrides config)
    --version               Show version information

EXAMPLES:
    $SCRIPT_NAME 1000
    $SCRIPT_NAME 1500.75 --verbose
    $SCRIPT_NAME 2000 --dry-run
    $SCRIPT_NAME 500 --glmr-ratio 0.7 --movr-ratio 0.3
    $SCRIPT_NAME 1000 0x1234567890123456789012345678901234567890
    $SCRIPT_NAME 2000 0xabcdefabcdefabcdefabcdefabcdefabcdefabcd --verbose

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
            --council-threshold)
                COUNCIL_THRESHOLD="$2"
                shift 2
                ;;
            --council-length-bound)
                COUNCIL_LENGTH_BOUND="$2"
                shift 2
                ;;
            --moonbeam-ws)
                MOONBEAM_WS_ENDPOINT="$2"
                shift 2
                ;;
            --moonriver-ws)
                MOONRIVER_WS_ENDPOINT="$2"
                shift 2
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --markdown|--md-table)
                MARKDOWN_OUTPUT=true
                shift
                ;;
            --proxy)
                PROXY_ENABLED=true
                shift
                ;;
            --proxy-address)
                PROXY_ENABLED=true
                PROXY_ADDRESS="$2"
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
                elif [[ -z "$RECIPIENT_ADDRESS" ]]; then
                    RECIPIENT_ADDRESS="$1"
                else
                    log "ERROR" "Too many arguments specified"
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
        COUNCIL_THRESHOLD=$(jq -r '.council_threshold // 3' "$CONFIG_FILE" 2>/dev/null || echo "3")
        COUNCIL_LENGTH_BOUND=$(jq -r '.council_length_bound // 10000' "$CONFIG_FILE" 2>/dev/null || echo "10000")
        MOONBEAM_WS_ENDPOINT=$(jq -r '.websocket_endpoints.moonbeam // "wss://wss.api.moonbeam.network"' "$CONFIG_FILE" 2>/dev/null || echo "wss://wss.api.moonbeam.network")
        MOONRIVER_WS_ENDPOINT=$(jq -r '.websocket_endpoints.moonriver // "wss://wss.api.moonriver.moonbeam.network"' "$CONFIG_FILE" 2>/dev/null || echo "wss://wss.api.moonriver.moonbeam.network")
        if [[ -z "$PROXY_ADDRESS" ]]; then
            PROXY_ADDRESS=$(jq -r '.proxy_address // empty' "$CONFIG_FILE" 2>/dev/null || echo "")
        fi
        else
        log "WARN" "jq not available, using default values"
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

    # Check for reasonable maximum (1 billion USD)
    if [[ $(echo "$USD_AMOUNT > 1000000000" | bc -l) == "1" ]]; then
        log "ERROR" "USD amount seems too large (> 1 billion). Please verify the amount."
        exit 1
    fi

    log "INFO" "USD amount validated: $USD_AMOUNT"
}

# Validate recipient address
validate_recipient_address() {
    if [[ -n "$RECIPIENT_ADDRESS" ]]; then
        # Check if it's a valid Ethereum-style address
        if ! echo "$RECIPIENT_ADDRESS" | grep -Eq '^0x[a-fA-F0-9]{40}$'; then
            log "ERROR" "Recipient address must be a valid Ethereum-style address (0x followed by 40 hex characters)"
            exit 1
        fi
        
        # Check for common invalid addresses
        if [[ "$RECIPIENT_ADDRESS" == "0x0000000000000000000000000000000000000000" ]]; then
            log "ERROR" "Recipient address cannot be the zero address"
            exit 1
        fi
        
        log "INFO" "Recipient address validated: $RECIPIENT_ADDRESS"
    fi
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

# Get latest proposal ID for a network
get_latest_proposal_id() {
    local network=$1
    local timeout=${2:-$DEFAULT_TIMEOUT}

    log "INFO" "Fetching latest proposal ID for $network"

    local html_url="https://${network}.subscan.io/treasury_council"
    local proposal_id
    proposal_id=$(curl -s --max-time "$timeout" "$html_url" | grep -oE 'treasury_council/[0-9]+' | head -1 | grep -oE '[0-9]+')
    
    if [[ -n "$proposal_id" ]]; then
        # Increment by 1 for the next proposal
        local next_proposal_id
        next_proposal_id=$((proposal_id + 1))
        log "SUCCESS" "Got latest proposal ID $proposal_id for $network, next proposal will be $next_proposal_id"
        echo "$next_proposal_id"
        return 0
    else
        log "ERROR" "Failed to fetch proposal ID for $network"
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
            # Only output the price value, not logs
            printf "%s" "$formatted_price"
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

    # Get recent blocks in sequential order
    log "INFO" "Fetching Moonbeam block..."
    local moonbeam_block
    moonbeam_block=$(get_recent_block "moonbeam")
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to get Moonbeam block"
        exit 1
    fi

    log "INFO" "Fetching Moonriver block..."
    local moonriver_block
    moonriver_block=$(get_recent_block "moonriver")
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to get Moonriver block"
        exit 1
    fi

    log "INFO" "Fetching GLMR price for block $moonbeam_block..."
    local glmr_price
    glmr_price=$(get_token_price "moonbeam" "GLMR" "$moonbeam_block")
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to get GLMR price"
        exit 1
    fi

    log "INFO" "Fetching MOVR price for block $moonriver_block..."
    local movr_price
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

# Generate council proposal call data using Node.js script
generate_council_proposal() {
    local network=$1
    local amount_planck=$2
    local recipient=$3
    local threshold=${4:-3}
    local length_bound=${5:-10000}
    local proxy_address=${6:-""}

    log "INFO" "Generating council proposal call data for $network"
    log "INFO" "Amount: $amount_planck planck, Recipient: $recipient"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Mock council proposal call data generation"
        echo "0x1234567890abcdef"  # Mock hex data
        return 0
    fi

    # Check if Node.js script exists
    if [[ ! -f "generate-council-proposal.js" ]]; then
        log "ERROR" "Node.js script generate-council-proposal.js not found"
        return 1
    fi

    # Check if Node.js is available
    if ! command -v node &> /dev/null; then
        log "ERROR" "Node.js is not installed. Please install Node.js to generate council proposal call data."
        return 1
    fi

    # Run Node.js script and capture output
    local node_output
    local ws_endpoint
    if [[ "$network" == "moonbeam" ]]; then
        ws_endpoint="$MOONBEAM_WS_ENDPOINT"
    else
        ws_endpoint="$MOONRIVER_WS_ENDPOINT"
    fi
    log "INFO" "Running Node.js script for $network..."
    node_output=$(node generate-council-proposal.js "$network" "$recipient" "$amount_planck" "$threshold" "$length_bound" "$ws_endpoint" "$proxy_address" 2>&1)
    local node_exit_code=$?

    if [[ $node_exit_code -ne 0 ]]; then
        log "ERROR" "Node.js script failed with exit code $node_exit_code"
        log "ERROR" "Node.js output: $node_output"
        return 1
    fi

    # Extract the full encoded call from the output (robust for both normal and proxy cases)
    local call_data
    call_data=$(awk '/Full Encoded Call:$/ {getline; print $0}' <<< "$node_output" | tail -1 | xargs)
    if [[ -z "$call_data" ]]; then
        call_data=$(awk '/Full Encoded Call \(Proxy\):$/ {getline; print $0}' <<< "$node_output" | tail -1 | xargs)
    fi

    if [[ -n "$call_data" ]]; then
        log "SUCCESS" "Generated council proposal call data for $network: $call_data"
        echo "$call_data"
        return 0
    else
        log "ERROR" "Failed to extract call data from Node.js output"
        return 1
    fi
}

# Buffer for council proposal logs
COUNCIL_LOGS=""
log_to_buffer() {
    local level=$1
    shift
    local message="$*"
    COUNCIL_LOGS+="[$level] $message\n"
}

# Format amount to planck (smallest unit)
format_to_planck() {
    local amount=$1
    local decimals=18  # Moonbeam/Moonriver use 18 decimals
    
    # Convert to planck (multiply by 10^18) and ensure it's an integer
    local planck_amount
    planck_amount=$(LC_NUMERIC=C echo "scale=0; $amount * 10^$decimals" | bc | sed 's/\..*$//')
    
    echo "$planck_amount"
}

# Portable thousands separator and two-decimal formatting function
format_number() {
    # Usage: format_number 1234567.8912
    # Force US locale and simple 2-decimal formatting
    LC_NUMERIC=C printf "%.2f\n" "$1"
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

    # Validate recipient address if provided
    validate_recipient_address

    log "INFO" "Processing USD amount: $USD_AMOUNT"
    log "INFO" "Using ratios: GLMR=$GLMR_RATIO, MOVR=$MOVR_RATIO"
    if [[ -n "$RECIPIENT_ADDRESS" ]]; then
        log "INFO" "Recipient address provided: $RECIPIENT_ADDRESS"
    fi

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

    # Generate council proposal call data if recipient address is provided
    local moonbeam_call_data=""
    local moonriver_call_data=""
    local moonbeam_proxy_call_data=""
    local moonriver_proxy_call_data=""
    local moonbeam_proposal_id=""
    local moonriver_proposal_id=""
    if [[ -n "$RECIPIENT_ADDRESS" ]]; then
        log "INFO" "Fetching proposal IDs for council proposals"
        
        log "INFO" "Fetching Moonbeam proposal ID..."
        moonbeam_proposal_id=$(get_latest_proposal_id "moonbeam")
        if [[ $? -ne 0 ]]; then
            log "WARN" "Failed to get Moonbeam proposal ID, will not show proposal ID"
            moonbeam_proposal_id=""
        fi
        
        log "INFO" "Fetching Moonriver proposal ID..."
        moonriver_proposal_id=$(get_latest_proposal_id "moonriver")
        if [[ $? -ne 0 ]]; then
            log "WARN" "Failed to get Moonriver proposal ID, will not show proposal ID"
            moonriver_proposal_id=""
        fi

        # Convert GLMR amount to planck (use rounded value for planck conversion)
        local glmr_amount_rounded
        glmr_amount_rounded=$(format_number "${glmr_amount:-0}")
        local glmr_planck
        glmr_planck=$(format_to_planck "$glmr_amount_rounded")
        
        # Convert MOVR amount to planck (use rounded value for planck conversion)
        local movr_amount_rounded
        movr_amount_rounded=$(format_number "${movr_amount:-0}")
        local movr_planck
        movr_planck=$(format_to_planck "$movr_amount_rounded")
        
        # Generate normal call data
        log "INFO" "Generating Moonbeam council proposal call data"
        moonbeam_call_data=$(generate_council_proposal "moonbeam" "$glmr_planck" "$RECIPIENT_ADDRESS")
        
        log "INFO" "Generating Moonriver council proposal call data"
        moonriver_call_data=$(generate_council_proposal "moonriver" "$movr_planck" "$RECIPIENT_ADDRESS")
        # If proxy is enabled and proxy address is set, generate proxy call data
        if [[ "$PROXY_ENABLED" == "true" && -n "$PROXY_ADDRESS" ]]; then
            log "INFO" "Generating Moonbeam proxy council proposal call data (proxy: $PROXY_ADDRESS)"
            moonbeam_proxy_call_data=$(generate_council_proposal "moonbeam" "$glmr_planck" "$RECIPIENT_ADDRESS" "$COUNCIL_THRESHOLD" "$COUNCIL_LENGTH_BOUND" "$PROXY_ADDRESS")
            log "INFO" "Generating Moonriver proxy council proposal call data (proxy: $PROXY_ADDRESS)"
            moonriver_proxy_call_data=$(generate_council_proposal "moonriver" "$movr_planck" "$RECIPIENT_ADDRESS" "$COUNCIL_THRESHOLD" "$COUNCIL_LENGTH_BOUND" "$PROXY_ADDRESS")
        fi
    fi



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

    # Format USD amount with commas and proper decimals
    local usd_amount_formatted
    usd_amount_formatted=$(format_number "${USD_AMOUNT:-0}")

    # Format amounts with explicit dot decimal separator and error handling
    local glmr_amount_formatted
    glmr_amount_formatted=$(LC_NUMERIC=C echo "scale=2; $glmr_amount" | bc)
    local movr_amount_formatted
    movr_amount_formatted=$(LC_NUMERIC=C echo "scale=2; $movr_amount" | bc)
    
    # Format prices with proper decimals and leading zeros
    local glmr_price_formatted
    glmr_price_formatted=$(LC_NUMERIC=C echo "scale=2; $glmr_price" | bc)
    # Ensure leading zero for values less than 1
    if [[ "$glmr_price_formatted" =~ ^\.[0-9]+$ ]]; then
        glmr_price_formatted="0$glmr_price_formatted"
    fi
    
    local movr_price_formatted
    movr_price_formatted=$(LC_NUMERIC=C echo "scale=2; $movr_price" | bc)
    # Ensure leading zero for values less than 1
    if [[ "$movr_price_formatted" =~ ^\.[0-9]+$ ]]; then
        movr_price_formatted="0$movr_price_formatted"
    fi

    # After calculation in main:
    # Format numbers for display
    usd_amount_formatted=$(format_number "${USD_AMOUNT:-0}")
    glmr_usd_share_formatted=$(format_number "${glmr_usd_share:-0}")
    movr_usd_share_formatted=$(format_number "${movr_usd_share:-0}")
    glmr_amount_formatted_disp=$(format_number "${glmr_amount_formatted:-0}")
    movr_amount_formatted_disp=$(format_number "${movr_amount_formatted:-0}")
    glmr_price_formatted_disp=$(LC_NUMERIC=C printf "%.4f" "$glmr_price_formatted")
    movr_price_formatted_disp=$(LC_NUMERIC=C printf "%.4f" "$movr_price_formatted")
    
    # Output summary
    if [[ "$MARKDOWN_OUTPUT" == "true" ]]; then
        echo
        printf "| %-15s | %-15s |\n" "Field" "Value"
        echo "|-----------------|-----------------|"
        printf "| %-15s | %-15s |\n" "USD Amount" "$usd_amount_formatted"
        printf "| %-15s | %-15s |\n" "GLMR Allocation" "$glmr_usd_share_formatted USD"
        printf "| %-15s | %-15s |\n" "MOVR Allocation" "$movr_usd_share_formatted USD"
        printf "| %-15s | %-15s |\n" "GLMR 30d EMA Price" "$glmr_price_formatted_disp USD"
        printf "| %-15s | %-15s |\n" "MOVR 30d EMA Price" "$movr_price_formatted_disp USD"
        printf "| %-15s | %-15s |\n" "GLMR Amount" "$glmr_amount_formatted_disp"
        printf "| %-15s | %-15s |\n" "MOVR Amount" "$movr_amount_formatted_disp"
        printf "| %-15s | %-15s |\n" "Moonbeam Block" "$moonbeam_block"
        printf "| %-15s | %-15s |\n" "Moonriver Block" "$moonriver_block"
        echo
    else
        echo
    echo "=================================="
        echo "=== PAYOUT CALCULATION RESULTS ==="
        echo "=================================="
        echo
        echo "USD Amount: $usd_amount_formatted"
        echo "GLMR Allocation: $glmr_usd_share_formatted USD"
        echo "MOVR Allocation: $movr_usd_share_formatted USD"
        echo "GLMR 30d EMA Price: $glmr_price_formatted_disp USD"
        echo "MOVR 30d EMA Price: $movr_price_formatted_disp USD"
        echo "GLMR Amount: $glmr_amount_formatted_disp"
        echo "MOVR Amount: $movr_amount_formatted_disp"
        echo "Moonbeam Block: $moonbeam_block"
        echo "Moonriver Block: $moonriver_block"
        echo
    fi

    # Add a blank line between payout and council proposal sections

    # Generate simple output format (only for non-JSON output)
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        cat << EOF

Moonbeam
========
- 30d EMA GLMR price block: $moonbeam_block
- https://moonbeam.subscan.io/tools/price_converter?value=1&type=block&from=GLMR&to=USD&time=$moonbeam_block
- $(LC_NUMERIC=C echo "$GLMR_RATIO * 100" | bc -l | LC_NUMERIC=C xargs printf "%.0f")% share in GLMR: $glmr_amount_formatted_disp
- https://moonbeam.subscan.io/tools/price_converter?value=$glmr_amount_formatted_disp&type=block&from=GLMR&to=USD&time=$moonbeam_block

Moonriver
=========
- 30d EMA MOVR price block: $moonriver_block
- https://moonriver.subscan.io/tools/price_converter?value=1&type=block&from=MOVR&to=USD&time=$moonriver_block
- $(LC_NUMERIC=C echo "$MOVR_RATIO * 100" | bc -l | LC_NUMERIC=C xargs printf "%.0f")% share in MOVR: $movr_amount_formatted_disp
- https://moonriver.subscan.io/tools/price_converter?value=$movr_amount_formatted_disp&type=block&from=MOVR&to=USD&time=$moonriver_block
EOF
    fi

    # Display council proposal call data if recipient address is provided
    if [[ -n "$RECIPIENT_ADDRESS" ]]; then
        # Council proposal output (no duplicate call data/decode link)
        if [[ -n "$moonbeam_call_data" && -n "$moonriver_call_data" ]]; then
            if [[ "$JSON_OUTPUT" != "true" ]]; then
                echo
                echo "=================================="
                echo "=== COUNCIL PROPOSAL CALL DATA ==="
                echo "=================================="
                echo
                echo "Moonbeam Council Proposal"
                echo "========================="
                if [[ -n "$moonbeam_proposal_id" ]]; then
                    echo "- Proposal ID: $moonbeam_proposal_id"
                fi
                echo "- Amount: $glmr_amount_formatted_disp GLMR ($glmr_planck Planck)"
                echo "- Recipient: $RECIPIENT_ADDRESS"
                echo "- Council Proposal Call Data: $moonbeam_call_data"
                echo "- Decode Link: https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fwss.api.moonbeam.network#/extrinsics/decode/$moonbeam_call_data"
                if [[ "$PROXY_ENABLED" == "true" && -n "$moonbeam_proxy_call_data" ]]; then
                    echo "- Proxy Address: $PROXY_ADDRESS"
                    echo "- Proxy Council Proposal Call Data: $moonbeam_proxy_call_data"
                    echo "- Proxy Decode Link: https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fwss.api.moonbeam.network#/extrinsics/decode/$moonbeam_proxy_call_data"
                fi
                echo
                echo "Moonriver Council Proposal"
                echo "=========================="
                if [[ -n "$moonriver_proposal_id" ]]; then
                    echo "- Proposal ID: $moonriver_proposal_id"
                fi
                echo "- Amount: $movr_amount_formatted_disp MOVR ($movr_planck Planck)"
                echo "- Recipient: $RECIPIENT_ADDRESS"
                echo "- Council Proposal Call Data: $moonriver_call_data"
                echo "- Decode Link: https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fwss.api.moonriver.moonbeam.network#/extrinsics/decode/$moonriver_call_data"
                if [[ "$PROXY_ENABLED" == "true" && -n "$moonriver_proxy_call_data" ]]; then
                    echo "- Proxy Address: $PROXY_ADDRESS"
                    echo "- Proxy Council Proposal Call Data: $moonriver_proxy_call_data"
                    echo "- Proxy Decode Link: https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fwss.api.moonriver.moonbeam.network#/extrinsics/decode/$moonriver_proxy_call_data"
                fi
                echo
                echo "=================================="
            else
                echo
                echo "=================================="
                echo "=== COUNCIL PROPOSAL CALL DATA ==="
                echo "=================================="
                echo
                echo "Moonbeam Council Proposal"
                echo "========================="
                if [[ -n "$moonbeam_proposal_id" ]]; then
                    echo "- Proposal ID: $moonbeam_proposal_id"
                fi
                echo "- Amount: $glmr_amount_formatted_disp GLMR ($glmr_planck Planck)"
                echo "- Recipient: $RECIPIENT_ADDRESS"
                echo "- Council Proposal Call Data: $moonbeam_call_data"
                echo "- Decode Link: https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fwss.api.moonbeam.network#/extrinsics/decode/$moonbeam_call_data"
                if [[ "$PROXY_ENABLED" == "true" && -n "$moonbeam_proxy_call_data" ]]; then
                    echo "- Proxy Address: $PROXY_ADDRESS"
                    echo "- Proxy Council Proposal Call Data: $moonbeam_proxy_call_data"
                    echo "- Proxy Decode Link: https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fwss.api.moonbeam.network#/extrinsics/decode/$moonbeam_proxy_call_data"
                fi
                echo
                echo "Moonriver Council Proposal"
                echo "=========================="
                if [[ -n "$moonriver_proposal_id" ]]; then
                    echo "- Proposal ID: $moonriver_proposal_id"
                fi
                echo "- Amount: $movr_amount_formatted_disp MOVR ($movr_planck Planck)"
                echo "- Recipient: $RECIPIENT_ADDRESS"
                echo "- Council Proposal Call Data: $moonriver_call_data"
                echo "- Decode Link: https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fwss.api.moonriver.moonbeam.network#/extrinsics/decode/$moonriver_call_data"
                if [[ "$PROXY_ENABLED" == "true" && -n "$moonriver_proxy_call_data" ]]; then
                    echo "- Proxy Address: $PROXY_ADDRESS"
                    echo "- Proxy Council Proposal Call Data: $moonriver_proxy_call_data"
                    echo "- Proxy Decode Link: https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fwss.api.moonriver.moonbeam.network#/extrinsics/decode/$moonriver_proxy_call_data"
                fi
                echo
                echo "=================================="
            fi
        else
            if [[ "$JSON_OUTPUT" != "true" ]]; then
                echo
                echo "=================================="
                echo "=== COUNCIL PROPOSAL CALL DATA ==="
                echo "=================================="
                echo
                echo "Error: Failed to generate council proposal call data."
                echo "Please ensure Node.js is installed and generate-council-proposal.js is available."
                echo
                echo "=================================="
                echo
            fi
        fi
    fi

    # Save to file (only for non-JSON output)
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        {
            echo "=================================="
            echo "=== PAYOUT CALCULATION RESULTS ==="
            echo "=================================="
            echo
            echo "USD Amount: $usd_amount_formatted"
            echo "GLMR Allocation: $glmr_usd_share_formatted USD"
            echo "MOVR Allocation: $movr_usd_share_formatted USD"
            echo "GLMR Price: $glmr_price_formatted_disp USD"
            echo "MOVR Price: $movr_price_formatted_disp USD"
            echo "GLMR Amount: $glmr_amount_formatted_disp"
            echo "MOVR Amount: $movr_amount_formatted_disp"
            echo "Moonbeam Block: $moonbeam_block"
            echo "Moonriver Block: $moonriver_block"
            echo
            echo "Moonbeam"
            echo "========"
            echo "- 30d EMA GLMR price block: $moonbeam_block"
            echo "- https://moonbeam.subscan.io/tools/price_converter?value=1&type=block&from=GLMR&to=USD&time=$moonbeam_block"
            echo "- $(LC_NUMERIC=C echo "$GLMR_RATIO * 100" | bc -l | LC_NUMERIC=C xargs printf "%.0f")% share in GLMR: $glmr_amount_formatted_disp"
            echo "- https://moonbeam.subscan.io/tools/price_converter?value=$glmr_amount_formatted_disp&type=block&from=GLMR&to=USD&time=$moonbeam_block"
            echo
            echo "Moonriver"
            echo "========="
            echo "- 30d EMA MOVR price block: $moonriver_block"
            echo "- https://moonriver.subscan.io/tools/price_converter?value=1&type=block&from=MOVR&to=USD&time=$moonriver_block"
            echo "- $(LC_NUMERIC=C echo "$MOVR_RATIO * 100" | bc -l | LC_NUMERIC=C xargs printf "%.0f")% share in MOVR: $movr_amount_formatted_disp"
            echo "- https://moonriver.subscan.io/tools/price_converter?value=$movr_amount_formatted_disp&type=block&from=MOVR&to=USD&time=$moonriver_block"
            
            # Add call data to output file if recipient was provided
            if [[ -n "$RECIPIENT_ADDRESS" ]]; then
                if [[ -n "$moonbeam_call_data" && -n "$moonriver_call_data" ]]; then
                    echo
                    echo "=================================="
                    echo "=== COUNCIL PROPOSAL CALL DATA ==="
                    echo "=================================="
                    echo
                    echo "Moonbeam Council Proposal"
                    echo "========================="
                    if [[ -n "$moonbeam_proposal_id" ]]; then
                        echo "- Proposal ID: $moonbeam_proposal_id"
                    fi
                    echo "- Amount: $glmr_amount_formatted_disp GLMR ($glmr_planck Planck)"
                    echo "- Recipient: $RECIPIENT_ADDRESS"
                    echo "- Council Proposal Call Data: $moonbeam_call_data"
                    echo "- Decode Link: https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fwss.api.moonbeam.network#/extrinsics/decode/$moonbeam_call_data"
                    if [[ "$PROXY_ENABLED" == "true" && -n "$moonbeam_proxy_call_data" ]]; then
                        echo "- Proxy Address: $PROXY_ADDRESS"
                        echo "- Proxy Council Proposal Call Data: $moonbeam_proxy_call_data"
                        echo "- Proxy Decode Link: https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fwss.api.moonbeam.network#/extrinsics/decode/$moonbeam_proxy_call_data"
                    fi
                    echo
                    echo "Moonriver Council Proposal"
                    echo "=========================="
                    if [[ -n "$moonriver_proposal_id" ]]; then
                        echo "- Proposal ID: $moonriver_proposal_id"
                    fi
                    echo "- Amount: $movr_amount_formatted_disp MOVR ($movr_planck Planck)"
                    echo "- Recipient: $RECIPIENT_ADDRESS"
                    echo "- Council Proposal Call Data: $moonriver_call_data"
                    echo "- Decode Link: https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fwss.api.moonriver.moonbeam.network#/extrinsics/decode/$moonriver_call_data"
                    if [[ "$PROXY_ENABLED" == "true" && -n "$moonriver_proxy_call_data" ]]; then
                        echo "- Proxy Address: $PROXY_ADDRESS"
                        echo "- Proxy Council Proposal Call Data: $moonriver_proxy_call_data"
                        echo "- Proxy Decode Link: https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fwss.api.moonriver.moonbeam.network#/extrinsics/decode/$moonriver_proxy_call_data"
                    fi
                    echo
                    echo "=================================="
                else
                    echo
                    echo "=================================="
                    echo "=== COUNCIL PROPOSAL CALL DATA ==="
                    echo "=================================="
                    echo
                    echo "Error: Failed to generate council proposal call data."
                    echo "Please ensure Node.js is installed and generate-council-proposal.js is available."
                    echo
                    echo "=================================="
                fi
            fi
    } > "$OUTPUT_FILE"
    fi
    
    if [[ "$JSON_OUTPUT" != "true" ]]; then
    log "SUCCESS" "Output saved to $OUTPUT_FILE"
    fi
    log "INFO" "Script completed successfully"
}

# Run main function with all arguments
main "$@"
