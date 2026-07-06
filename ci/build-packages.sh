#!/bin/bash
# Akatsuki Linux - Package Build Script
# Builds all .deb packages from the packages/ directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_DIR/build/debs}"
REPREPRO_DIR="${REPREPRO_DIR:-$PROJECT_DIR/build/apt-repo}"

# Ensure output directories exist
mkdir -p "$OUTPUT_DIR"
mkdir -p "$REPREPRO_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "============================================"
echo "  Akatsuki Linux - Building Packages"
echo "============================================"

# Check for build dependencies
for cmd in dpkg-buildpackage lintian; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd not found. Please install build-essential, debhelper, lintian."
        exit 1
    fi
done

# Initialize reprepro repository
if command -v reprepro &>/dev/null; then
    if [ ! -f "$REPREPRO_DIR/conf/distributions" ]; then
        mkdir -p "$REPREPRO_DIR/conf"
        cat > "$REPREPRO_DIR/conf/distributions" << 'DISTRIB'
Origin: Akatsuki Linux
Label: Akatsuki Linux Repository
Suite: trixie
Codename: trixie
Architectures: amd64 source
Components: main
Description: Akatsuki Linux APT Repository
DISTRIB
    fi
    REPREPRO_CMD="reprepro -b $REPREPRO_DIR"
else
    REPREPRO_CMD=""
    echo -e "${YELLOW}Warning: reprepro not found. Packages will be built but not added to repo.${NC}"
fi

# Function to build a package
build_package() {
    local pkg_dir="$1"
    local pkg_name=$(basename "$pkg_dir")

    echo ""
    echo -e "${YELLOW}Building package: ${pkg_name}${NC}"
    echo "----------------------------------------"

    if [ ! -d "$pkg_dir/debian" ]; then
        echo -e "${RED}ERROR: $pkg_name has no debian/ directory. Skipping.${NC}"
        return 1
    fi

    pushd "$pkg_dir" > /dev/null

    # Clean any previous builds
    if [ -f debian/files ]; then
        dh_clean 2>/dev/null || true
    fi

    # Build the package
    dpkg-buildpackage -us -uc -b 2>&1 | tail -5

    # Copy resulting .deb files
    local deb_files
    deb_files=$(ls ../*.deb 2>/dev/null || true)
    if [ -n "$deb_files" ]; then
        cp ../*.deb "$OUTPUT_DIR/" 2>/dev/null || true
        cp ../*.tar.* ../*.dsc ../*.changes ../*.buildinfo "$OUTPUT_DIR/" 2>/dev/null || true
    fi

    # Run lintian
    for deb in $deb_files; do
        if [ -f "$deb" ]; then
            echo "Running lintian on $(basename "$deb")..."
            lintian --suppress-tags bad-distribution-in-changes-file "$deb" 2>/dev/null || true
        fi
    done

    # Add to local repository
    if [ -n "$REPREPRO_CMD" ]; then
        for deb in $deb_files; do
            if [ -f "$deb" ]; then
                echo "Adding $(basename "$deb") to local repo..."
                $REPREPRO_CMD includedeb trixie "$deb" 2>/dev/null || echo "Warning: failed to add $deb to repo"
            fi
        done
    fi

    popd > /dev/null
    echo -e "${GREEN}✓ ${pkg_name} built successfully${NC}"
}

# Build all packages
BUILT_COUNT=0
FAIL_COUNT=0

for pkg_dir in "$PROJECT_DIR/packages/"*/; do
    if [ -d "$pkg_dir/debian" ]; then
        if build_package "$pkg_dir"; then
            BUILT_COUNT=$((BUILT_COUNT + 1))
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    fi
done

echo ""
echo "============================================"
echo "  Build Summary"
echo "============================================"
echo -e "${GREEN}Successfully built: ${BUILT_COUNT} packages${NC}"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo -e "${RED}Failed: ${FAIL_COUNT} packages${NC}"
fi
echo "Output directory: $OUTPUT_DIR"
echo "Repository directory: $REPREPRO_DIR"
echo ""
echo "Done."

exit $FAIL_COUNT
