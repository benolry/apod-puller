#!/bin/bash

# Fail early behavior:
# -e: exit on error, -u: error on unset variables, -o pipefail: catch errors in pipes
set -euo pipefail

# Check if required tools are installed
for cmd in curl magick identify plasma-apply-wallpaperimage; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: '$cmd' is not installed." >&2
        exit 1
    fi
done

# Short delay in case the system is still booting
sleep 3

# Create cache directory if it doesn't exist
CACHE_DIR="$HOME/.cache/apod"
mkdir -p "$CACHE_DIR"

# 1. Fetch the APOD main page
#APOD_URL="https://apod.nasa.gov/apod/ap260316.html"
APOD_URL="https://apod.nasa.gov/apod/"
APOD_URL_PREFIX="https://apod.nasa.gov/apod/"

# Fetch HTML with fail-safe curl options
RESPONSE=$(curl -sfL "$APOD_URL") || { echo "Error: Failed to download APOD page"; exit 1; }

# Extract image link
IMG_PATH=$(echo "$RESPONSE" | grep -oP 'href="\Kimage/[^"]+\.(jpg|jpeg|png)' | head -1 || true)

if [ -z "$IMG_PATH" ]; then
    echo "No image found (maybe it's a video today?)."
    exit 1
fi

# Extract and clean Title and Explanation
TITLE=$(echo "$RESPONSE" | tr '\n' ' ' | grep -oP '<center>\s*<b>.*?<\/center>' | head -1 | sed 's/<[^>]*>//g; s/   / - /g; s/  */ /g; s/^ //g' | xargs -0)

echo "Title:"
echo "$TITLE"
echo

EXPLANATION=$(echo "$RESPONSE" | tr '\n' ' ' | grep -zoP '(?s)<b>\s*Explanation:\s*</b>.*?<p>' | tr -d '\0' | sed 's/<[^>]*>//g; s/  */ /g; s/^ //g' | xargs -0)

echo "Description:"
echo "$EXPLANATION"
echo

# Define file paths
FULL_IMG_URL="${APOD_URL_PREFIX}/${IMG_PATH}"
FILE_NAME=$(basename "$IMG_PATH")
ORIGINAL_IMAGE="$CACHE_DIR/$FILE_NAME"
TIMESTAMP=$(date +%3N)
WALLPAPER_FINAL="$CACHE_DIR/text-$TIMESTAMP-$FILE_NAME"

# Download and resize image (Min 1920, Max 3840)
if [ ! -f "$ORIGINAL_IMAGE" ]; then
    echo "Downloading new APOD: $FILE_NAME"
    curl -sfL -o "$ORIGINAL_IMAGE" "$FULL_IMG_URL"

    # Validate image
    if ! magick identify "$ORIGINAL_IMAGE" &> /dev/null; then
        echo "Error: The downloaded file is not a valid image."
        rm -f "$ORIGINAL_IMAGE"
        exit 1
    fi

    echo "Resizing image (Target: 1920px - 3840px width)..."

    # First: Ensure it's at least 1920px (upscale if smaller)
    magick "$ORIGINAL_IMAGE" -resize "1920x<" "$ORIGINAL_IMAGE"

    # Second: Ensure it's at most 3840px (downscale if larger)
    magick "$ORIGINAL_IMAGE" -resize "3840x>" "$ORIGINAL_IMAGE"
else
    echo "Original image already exists. No further files will be created."
    exit 1
fi

# Overlay text onto a copy of the image using ImageMagick
if [ ! -f "$WALLPAPER_FINAL" ]; then
    echo "Creating wallpaper with text overlay..."

    # Use a fixed file in the cache directory instead of mktemp
    PANGO_FILE="$CACHE_DIR/pango_input.txt"

    # Pre-clean: Remove old temp file if it exists
    rm -f "$PANGO_FILE"

    # CRITICAL: Improved escaping for Pango (handles &, <, >, ", ')
    TITLE_ESC=$(echo "$TITLE" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&apos;/g')
    TEXT_ESC=$(echo "$EXPLANATION" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&apos;/g')

    # Write to the fixed file
    echo -e "<b>$TITLE_ESC</b>\n\n$TEXT_ESC" > "$PANGO_FILE"

    echo "Starting Magick processing..."

    # Dimensionen sicher einlesen (ohne versteckte Leerzeichen)
    IMG_W=$(identify -format "%w" "$ORIGINAL_IMAGE")
    IMG_H=$(identify -format "%h" "$ORIGINAL_IMAGE")

    # width of the text block
    TEXT_WIDTH=$(python3 -c "print(int($IMG_W * 0.8))")
    # font-size
    FONT_SIZE=$(python3 -c "print(int($IMG_W / 240))")
    # Offset calcuation meant to position the text block to be viewed on 16/9 displays
    OFFSET_Y=$(python3 -c "print(int($IMG_H - $IMG_W / 16 * 9 - ($IMG_H - $IMG_W / 16 * 9) / 2))")

    echo "Debug: W=$IMG_W, H=$IMG_H, TextWidth=$TEXT_WIDTH, OffsetY=$OFFSET_Y"

    # 5. image manipulation
    magick "$ORIGINAL_IMAGE" \
        \( -size "${TEXT_WIDTH}x" \
           -background "rgba(0,0,0,0.0)" \
           -fill "#D3D3D3" \
           -font "sans" \
           -pointsize "$FONT_SIZE" \
           pango:@"$PANGO_FILE" \
           -bordercolor "rgba(0,0,0,0.6)" \
           -border "24x12" \
        \) -gravity south \
        -geometry "+0+${OFFSET_Y}" \
        -composite "$WALLPAPER_FINAL"
    # Check if file exists now
    if [ ! -f "$WALLPAPER_FINAL" ]; then
        echo "CRITICAL: Magick finished but NO FILE was created at $WALLPAPER_FINAL"
    fi

    # Apply the processed image as KDE Plasma wallpaper
    plasma-apply-wallpaperimage "$WALLPAPER_FINAL"
    echo "Success: Wallpaper with explanation has been set!"
else
    echo "Wallpaper with text already exists."
fi

# cleanup
rm -f "$PANGO_FILE"
