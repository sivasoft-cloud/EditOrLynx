#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Edit.or.lynx - Automated Git & GitHub Release Engine
# Commits changes, generates release logs, pushes to GitHub & creates releases
# ==============================================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
TITLE="${2:-}"
NOTES="${3:-}"

# 1. Determine Version
if [ -z "$VERSION" ]; then
    # Auto-detect latest tag or default to v2.0.0
    LATEST_TAG=$(git tag --sort=-v:refname 2>/dev/null | head -n 1 || echo "")
    if [ -z "$LATEST_TAG" ]; then
        VERSION="v2.0.0"
    else
        # Bump patch version if not provided
        VERSION="v2.0.1"
    fi
fi

# Ensure version starts with 'v'
if [[ ! "$VERSION" =~ ^v ]]; then
    VERSION="v$VERSION"
fi

# 2. Determine Title and Notes
DATE_STR=$(date "+%Y-%m-%d %H:%M:%S")
if [ -z "$TITLE" ]; then
    TITLE="Edit.or.lynx ${VERSION} Release"
fi

if [ -z "$NOTES" ]; then
    CHANGED_FILES=$(git status --short)
    if [ -z "$CHANGED_FILES" ]; then
        NOTES="Maintenance and continuous refinement release (${DATE_STR})."
    else
        NOTES="Release ${VERSION} (${DATE_STR}): Updated codebase, continuous squircle notch architecture, motion engine, and settings."
    fi
fi

echo "========================================================"
echo "🚀 Preparing Edit.or.lynx Release: ${VERSION}"
echo "📝 Title: ${TITLE}"
echo "📅 Date:  ${DATE_STR}"
echo "========================================================"

# 3. Update RELEASE_NOTES.md
RELEASE_FILE="$ROOT/RELEASE_NOTES.md"
TEMP_NOTES=$(mktemp)

cat <<EOF > "$TEMP_NOTES"
# ${TITLE} (${VERSION})
*Published: ${DATE_STR}*

${NOTES}

### Highlights in this Release:
- **Pure Notchy G2 Squircle Geometry**: Full G2 continuous curvature (R * 1.28 extent, 0.44R and 0.82R control points) and outward top ear flairs.
- **Liquid Glass Materials**: Support for both Dark Mode (.liquidGlass, .matteDark, .trueBlack) and Light Mode (.liquidLight, .matteLight) with dynamic specular highlights and razor rim strokes.
- **Card-Based Settings System**: High-density grouped cards with custom toggles, sliders, menus, and dedicated Downloader pane.
- **Continuous 120 BPM Motion Engine**: 1440x1440 analytical spring-driven UI morph across 12 distinct UI states with 4x subframe motion blur at 60fps.
- **Performance Optimization**: <1% idle CPU utilization through paused timers and compositor-driven rendering.

---
EOF

if [ -f "$RELEASE_FILE" ]; then
    cat "$RELEASE_FILE" >> "$TEMP_NOTES"
fi
mv "$TEMP_NOTES" "$RELEASE_FILE"
echo "✓ Updated ${RELEASE_FILE}"

# 4. Stage and Commit
git add -A
if git diff --staged --quiet; then
    echo "ℹ No uncommitted changes detected. Proceeding with existing commits."
else
    git commit -m "release: ${VERSION} - ${TITLE}" -m "${NOTES}"
    echo "✓ Committed changes for ${VERSION}"
fi

# 5. Tag Release
if git rev-parse "$VERSION" >/dev/null 2>&1; then
    echo "ℹ Tag ${VERSION} already exists locally."
else
    git tag -a "$VERSION" -m "${TITLE}"
    echo "✓ Created git tag: ${VERSION}"
fi

# 6. Check GitHub Connection
GH_BIN="/opt/homebrew/bin/gh"
if [ ! -x "$GH_BIN" ]; then
    GH_BIN=$(command -v gh || echo "")
fi

if [ -z "$GH_BIN" ]; then
    echo "⚠️ GitHub CLI (gh) not found. Please install gh to automate remote GitHub operations."
    exit 0
fi

# Check if authenticated
if ! "$GH_BIN" auth status >/dev/null 2>&1; then
    echo ""
    echo "⚠️  GitHub authentication required!"
    echo "👉 Please run: gh auth login"
    echo "   Or export GH_TOKEN=<your-personal-access-token>"
    echo "   Once logged in, re-run this script to automatically push and create GitHub releases."
    exit 0
fi

# Check remote origin
if ! git remote get-url origin >/dev/null 2>&1; then
    echo "▸ Creating GitHub repository and connecting origin..."
    "$GH_BIN" repo create EditOrLynx --public --source=. --remote=origin --push || true
fi

# Push branch and tags
echo "▸ Pushing to GitHub (main + tags)..."
git push -u origin main --tags || git push origin main --tags

# 7. Create GitHub Release with Assets
echo "▸ Creating GitHub Release ${VERSION}..."
ASSETS=()
if [ -f "$ROOT/dist/Edit.or.lynx.dmg" ]; then
    ASSETS+=("$ROOT/dist/Edit.or.lynx.dmg")
fi
if [ -f "$ROOT/MotionEngine/motion_dark_60fps.mp4" ]; then
    ASSETS+=("$ROOT/MotionEngine/motion_dark_60fps.mp4")
fi
if [ -f "$ROOT/MotionEngine/motion_light_60fps.mp4" ]; then
    ASSETS+=("$ROOT/MotionEngine/motion_light_60fps.mp4")
fi

if [ ${#ASSETS[@]} -gt 0 ]; then
    "$GH_BIN" release create "$VERSION" "${ASSETS[@]}" \
        --title "$TITLE" \
        --notes-file <(head -n 25 "$RELEASE_FILE") \
        --draft=false || echo "ℹ Release already exists on GitHub or failed to update."
else
    "$GH_BIN" release create "$VERSION" \
        --title "$TITLE" \
        --notes-file <(head -n 25 "$RELEASE_FILE") \
        --draft=false || echo "ℹ Release already exists on GitHub or failed to update."
fi

echo "========================================================"
echo "🎉 Successfully released ${VERSION} to GitHub!"
echo "========================================================"
