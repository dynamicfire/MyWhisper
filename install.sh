#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# MyWhisper Installation Script
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL_DIR="$HOME/models/whisper"
CONFIG_DIR="$HOME/.config/whisper"
BIN_DIR="$HOME/bin"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Model URLs
MODEL_LARGE_V3_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin?download=true"
MODEL_LARGE_V3_Q5_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q5_0.bin?download=true"

# Default options
SKIP_MODEL=false
UNINSTALL=false
MODEL_CHOICE=""

# ============================================================================
# Helper Functions
# ============================================================================

print_banner() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}${BOLD}       MyWhisper Installation Script       ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
    echo ""
}

log_step() {
    echo -e "\n${BOLD}[$1]${NC} $2"
}

log_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "  ${YELLOW}!${NC} $1"
}

log_error() {
    echo -e "  ${RED}✗${NC} $1"
}

log_info() {
    echo -e "  ${BLUE}→${NC} $1"
}

# ============================================================================
# Check Functions
# ============================================================================

check_macos() {
    log_step "1/6" "Checking system requirements..."

    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script only supports macOS"
        exit 1
    fi
    log_success "macOS detected"
}

check_homebrew() {
    if ! command -v brew &>/dev/null; then
        log_error "Homebrew not found"
        log_info "Install Homebrew first: https://brew.sh"
        exit 1
    fi
    log_success "Homebrew installed"
}

# ============================================================================
# Installation Functions
# ============================================================================

install_dependencies() {
    log_step "2/6" "Installing dependencies..."

    local deps=("whisper-cpp" "ffmpeg" "sox")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! brew list "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_info "brew install ${missing[*]}"
        brew install "${missing[@]}"
    fi

    log_success "Dependencies installed"
}

download_model() {
    log_step "3/6" "Downloading model..."

    mkdir -p "$MODEL_DIR"

    # Check if model already exists
    if [[ -f "$MODEL_DIR/ggml-large-v3.bin" ]] || [[ -f "$MODEL_DIR/ggml-large-v3-q5_0.bin" ]]; then
        log_warning "Model already exists in $MODEL_DIR"
        read -p "  ? Download again? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_success "Using existing model"
            return
        fi
    fi

    # Model selection
    if [[ -z "$MODEL_CHOICE" ]]; then
        echo "  ? Select model version:"
        echo "    1) ggml-large-v3.bin (1.5GB, most accurate) [recommended]"
        echo "    2) ggml-large-v3-q5_0.bin (1.1GB, quantized)"
        read -p "  Enter choice [1]: " -n 1 -r choice
        echo
        MODEL_CHOICE="${choice:-1}"
    fi

    local model_url model_file
    case "$MODEL_CHOICE" in
        2)
            model_url="$MODEL_LARGE_V3_Q5_URL"
            model_file="ggml-large-v3-q5_0.bin"
            ;;
        *)
            model_url="$MODEL_LARGE_V3_URL"
            model_file="ggml-large-v3.bin"
            ;;
    esac

    log_info "Downloading $model_file..."
    curl -L --progress-bar -o "$MODEL_DIR/$model_file" "$model_url"

    log_success "Model saved to $MODEL_DIR/$model_file"
}

create_prompt_file() {
    log_step "4/6" "Creating config files..."

    mkdir -p "$CONFIG_DIR"

    if [[ -f "$CONFIG_DIR/prompt.txt" ]]; then
        log_warning "prompt.txt already exists"
        read -p "  ? Overwrite? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_success "Using existing prompt.txt"
            return
        fi
    fi

    cp "$SCRIPT_DIR/prompt.txt" "$CONFIG_DIR/prompt.txt"

    log_success "$CONFIG_DIR/prompt.txt created"
}

deploy_scripts() {
    log_step "5/6" "Deploying scripts..."

    mkdir -p "$BIN_DIR"

    # Copy scripts from the repository
    cp "$SCRIPT_DIR/whisper_dictate.sh" "$BIN_DIR/"
    cp "$SCRIPT_DIR/whisper_toggle.sh" "$BIN_DIR/"

    chmod +x "$BIN_DIR/whisper_dictate.sh"
    chmod +x "$BIN_DIR/whisper_toggle.sh"

    log_success "$BIN_DIR/whisper_dictate.sh"
    log_success "$BIN_DIR/whisper_toggle.sh"
}

verify_installation() {
    log_step "6/6" "Verifying installation..."

    local all_ok=true

    # Check binaries
    for cmd in whisper-cli ffmpeg sox; do
        if command -v "$cmd" &>/dev/null; then
            log_success "$cmd: $(which $cmd)"
        else
            log_error "$cmd: not found"
            all_ok=false
        fi
    done

    # Check model
    if [[ -f "$MODEL_DIR/ggml-large-v3.bin" ]]; then
        log_success "Model: $MODEL_DIR/ggml-large-v3.bin"
    elif [[ -f "$MODEL_DIR/ggml-large-v3-q5_0.bin" ]]; then
        log_success "Model: $MODEL_DIR/ggml-large-v3-q5_0.bin"
    else
        log_error "Model: not found in $MODEL_DIR"
        all_ok=false
    fi

    # Check scripts
    for script in whisper_dictate.sh whisper_toggle.sh; do
        if [[ -x "$BIN_DIR/$script" ]]; then
            log_success "Script: $BIN_DIR/$script"
        else
            log_error "Script: $BIN_DIR/$script not found or not executable"
            all_ok=false
        fi
    done

    if [[ "$all_ok" == false ]]; then
        echo ""
        log_error "Some components are missing. Please check the errors above."
        exit 1
    fi
}

print_next_steps() {
    local username=$(whoami)

    echo ""
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Installation complete!${NC}"
    echo ""
    echo -e "${BOLD}Next steps (manual):${NC}"
    echo ""
    echo "1. Grant permissions (System Settings → Privacy & Security):"
    echo "   • Microphone → Enable Terminal and Shortcuts"
    echo "   • Accessibility → Enable Shortcuts"
    echo ""
    echo "2. Configure hotkey:"
    echo "   • Open Shortcuts app"
    echo "   • Create new shortcut with \"Run Shell Script\""
    echo "   • Script: /Users/$username/bin/whisper_toggle.sh"
    echo "   • Assign keyboard shortcut (e.g., ⌥Space)"
    echo ""
    echo "3. Test:"
    echo "   ~/bin/whisper_toggle.sh  # Start recording"
    echo "   ~/bin/whisper_toggle.sh  # Stop and transcribe"
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
}

# ============================================================================
# Uninstall Function
# ============================================================================

uninstall() {
    print_banner
    echo -e "${YELLOW}Uninstalling MyWhisper...${NC}"
    echo ""

    # Remove scripts
    if [[ -f "$BIN_DIR/whisper_dictate.sh" ]]; then
        rm -f "$BIN_DIR/whisper_dictate.sh"
        log_success "Removed $BIN_DIR/whisper_dictate.sh"
    fi
    if [[ -f "$BIN_DIR/whisper_toggle.sh" ]]; then
        rm -f "$BIN_DIR/whisper_toggle.sh"
        log_success "Removed $BIN_DIR/whisper_toggle.sh"
    fi

    # Ask about model
    if [[ -d "$MODEL_DIR" ]]; then
        read -p "  ? Remove model files in $MODEL_DIR? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$MODEL_DIR"
            log_success "Removed $MODEL_DIR"
        fi
    fi

    # Ask about config
    if [[ -f "$CONFIG_DIR/prompt.txt" ]]; then
        read -p "  ? Remove config in $CONFIG_DIR? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$CONFIG_DIR/prompt.txt"
            log_success "Removed $CONFIG_DIR/prompt.txt"
        fi
    fi

    # Clean temp directory
    if [[ -d "/tmp/mywhisper" ]]; then
        rm -rf "/tmp/mywhisper"
        log_success "Removed /tmp/mywhisper"
    fi

    echo ""
    echo -e "${GREEN}Uninstall complete!${NC}"
    echo ""
    echo "Note: Dependencies (whisper-cpp, ffmpeg, sox) were not removed."
    echo "Run 'brew uninstall whisper-cpp ffmpeg sox' to remove them."
}

# ============================================================================
# Parse Arguments
# ============================================================================

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --skip-model     Skip model download"
    echo "  --uninstall      Uninstall MyWhisper"
    echo "  --model 1|2      Pre-select model (1=large-v3, 2=quantized)"
    echo "  -h, --help       Show this help"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-model)
            SKIP_MODEL=true
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        --model)
            MODEL_CHOICE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# ============================================================================
# Main
# ============================================================================

main() {
    if [[ "$UNINSTALL" == true ]]; then
        uninstall
        exit 0
    fi

    print_banner

    check_macos
    check_homebrew

    install_dependencies

    if [[ "$SKIP_MODEL" == false ]]; then
        download_model
    else
        log_step "3/6" "Downloading model..."
        log_warning "Skipped (--skip-model)"
    fi

    create_prompt_file
    deploy_scripts
    verify_installation

    print_next_steps
}

main
