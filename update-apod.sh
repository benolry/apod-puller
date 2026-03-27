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
sleep 5

# Create cache directory if it doesn't exist
CACHE_DIR="$HOME/.cache/apod"
mkdir -p "$CACHE_DIR"

# 1. Fetch the APOD main page
APOD_URL="https://apod.nasa.gov/apod/"
APOD_URL_PREFIX="https://apod.nasa.gov/apod/"

# Fetch HTML with fail-safe curl options
RESPONSE=$(curl -sfL "$APOD_URL") || { echo "Error: Failed to download APOD page"; exit 1; }

# 2. Extract image link
IMG_PATH=$(echo "$RESPONSE" | grep -oP 'href="\Kimage/[^"]+\.(jpg|jpeg|png)' | head -1 || true)

if [ -z "$IMG_PATH" ]; then
    echo "No image found (maybe it's a video today?)."
    exit 1
fi

# 3. Extract and clean Title and Explanation
TITLE=$(echo "$RESPONSE" | tr '\n' ' ' | grep -oP '<center>\s*<b>.*?<\/center>' | head -1 | sed 's/<[^>]*>//g; s/   / - /g; s/  */ /g' | xargs -0)

echo "Title:"
echo "$TITLE"
echo

EXPLANATION=$(echo "$RESPONSE" | tr '\n' ' ' | grep -zoP '(?s)<b>\s*Explanation:\s*</b>.*?<p>' | tr -d '\0' | sed 's/<[^>]*>//g' | xargs -0)

echo "Description:"
echo "$EXPLANATION"
echo

# Define file paths
FULL_IMG_URL="${APOD_URL_PREFIX}/${IMG_PATH}"
FILE_NAME=$(basename "$IMG_PATH")
ORIGINAL_IMAGE="$CACHE_DIR/$FILE_NAME"
WALLPAPER_FINAL="$CACHE_DIR/text-$FILE_NAME"

# 4. Download image (only if it doesn't exist locally)
if [ ! -f "$ORIGINAL_IMAGE" ]; then
    echo "Downloading new APOD: $FILE_NAME"
    curl -sfL -o "$ORIGINAL_IMAGE" "$FULL_IMG_URL"

    # Validate if the downloaded file is a valid image
    if ! magick identify "$ORIGINAL_IMAGE" &> /dev/null; then
        echo "Error: The downloaded file is not a valid image."
        rm -f "$ORIGINAL_IMAGE"
        exit 1
    fi

    echo "Resizing image if necessary: $FILE_NAME"
    magick "$ORIGINAL_IMAGE" -resize "3840x>" "$ORIGINAL_IMAGE"
else
    echo "Original image already exists."
fi

# 5. Overlay text onto a copy of the image using ImageMagick
if [ ! -f "$WALLPAPER_FINAL" ]; then
    echo "Creating wallpaper with text overlay..."

    # Create a temporary file for Pango text to avoid argument list limits
    PANGO_FILE=$(mktemp)
    # Ensure the temp file is removed even if the script crashes
    trap 'rm -f "$PANGO_FILE"' EXIT

    # Escape special characters for Pango markup
    TITLE_ESC=$(echo "$TITLE" | sed 's/&/\&amp;/g')
    TEXT_ESC=$(echo "$EXPLANATION" | sed 's/&/\&amp;/g')

    echo -e "<b>$TITLE_ESC</b>\n\n$TEXT_ESC" > "$PANGO_FILE"

    # Get image dimensions
    read IMG_W IMG_H < <(identify -format "%w %h" "$ORIGINAL_IMAGE")

    # Run ImageMagick processing
    magick "$ORIGINAL_IMAGE" \
        \( -size "%[fx:${IMG_W}*0.8]" \
           -background "rgba(0,0,0,0)" \
           -fill "#D3D3D3" \
           -font "Liberation-Sans" \
           -pointsize %[fx:${IMG_W}/240] \
           pango:@"$PANGO_FILE" \
           -bordercolor "rgba(0,0,0,0.5)" \
           -border "24x12" \
        \) -gravity south \
        -geometry "+0+%[fx:${IMG_H}-${IMG_W}/16*9-(${IMG_H}-${IMG_W}/16*9)/2]" \
        -composite "$WALLPAPER_FINAL"

    # 6. Apply the processed image as KDE Plasma wallpaper
    plasma-apply-wallpaperimage "$WALLPAPER_FINAL"

    echo "Success: Wallpaper with explanation has been set!"
else
    echo "Wallpaper with text already exists."
fi
