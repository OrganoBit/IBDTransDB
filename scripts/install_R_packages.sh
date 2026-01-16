#!/usr/bin/env bash

# IBDTransDB - Automated R Package Installer
# This script installs all required R packages for the CLI and RShiny apps

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
R_INSTALL_SCRIPT="${SCRIPT_DIR}/r_analysis/install_packages.R"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}IBDTransDB - R Package Installation${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if R is installed
if ! command -v R &> /dev/null; then
    echo -e "${RED}Error: R is not installed or not in PATH${NC}"
    echo ""
    echo "Please install R first:"
    echo "  - macOS: brew install r"
    echo "  - Ubuntu: sudo apt-get install r-base r-base-dev"
    echo "  - Windows: Download from https://cloud.r-project.org/"
    echo ""
    echo "See docs/setup-instruction.md for detailed installation instructions."
    exit 1
fi

# Display R version
R_VERSION=$(R --version | head -n 1)
echo -e "${GREEN}✓${NC} Found R: ${R_VERSION}"
echo ""

# Check if installation script exists
if [ ! -f "${R_INSTALL_SCRIPT}" ]; then
    echo -e "${RED}Error: Installation script not found at ${R_INSTALL_SCRIPT}${NC}"
    exit 1
fi

echo -e "${BLUE}Starting R package installation...${NC}"
echo -e "${YELLOW}This may take several minutes depending on your system and internet speed.${NC}"
echo ""

# Run the R installation script
if Rscript "${R_INSTALL_SCRIPT}"; then
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}✓ Installation completed successfully!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Activate your Python virtual environment:"
    echo "     source .venv/bin/activate"
    echo ""
    echo "  2. Test the CLI:"
    echo "     ibdtransdb --help"
    echo "     ibdtransdb datasets list"
    echo ""
    echo "  3. Run RShiny apps:"
    echo "     cd IBDTransDB_Home && R -e \"shiny::runApp('IBDTransDB.R')\""
    echo ""
    exit 0
else
    EXIT_CODE=$?
    echo ""
    echo -e "${RED}================================================${NC}"
    echo -e "${RED}✗ Installation failed (exit code: ${EXIT_CODE})${NC}"
    echo -e "${RED}================================================${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check R installation: R --version"
    echo "  2. Ensure you have internet connectivity"
    echo "  3. On Linux, install system dependencies:"
    echo "     sudo apt-get install -y libcurl4-openssl-dev libssl-dev libxml2-dev"
    echo "  4. Try running the R script directly:"
    echo "     Rscript ${R_INSTALL_SCRIPT}"
    echo ""
    echo "See docs/setup-instruction.md for more help."
    exit 1
fi
