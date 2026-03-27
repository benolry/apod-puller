# APOD to KDE Wallpaper 🌌

A Bash script that automatically fetches NASA's **Astronomy Picture of the Day (APOD)**, adds the title and explanation as a text overlay, and sets it as your KDE Plasma wallpaper.

## Features
- **Auto-Fetch:** Downloads the latest image from NASA APOD.
- **Smart Overlay:** Uses ImageMagick & Pango to render the title and description directly onto the image.
- **Optimized:** Resizes images to 4K (3840px width) if necessary and caches them locally.
- **Robust:** Includes dependency checks and "fail-early" error handling.
- **KDE Integrated:** Uses `plasma-apply-wallpaperimage` for native wallpaper switching.

## Prerequisites
The script requires the following tools to be installed:
- `curl` (to download the HTML and images)
- `ImageMagick` (for image processing and `identify`)
- `Pango` (usually comes with ImageMagick, used for text formatting)
- `KDE Plasma` (for the wallpaper command)

On Arch Linux:
```bash
sudo pacman -S curl imagemagick
```
On Ubuntu/Debian:
```bash
sudo apt install curl imagemagick
```

## Installation
1. Clone the repository or download the script:
   ```bash
   git clone https://github.com/your-username/apod-kde-wallpaper.git
   cd apod-kde-wallpaper
   ```
2. Make the script executable:
   ```bash
   chmod +x apod_wallpaper.sh
   ```

## Usage
Simply run the script:
```bash
./apod_wallpaper.sh
```

### Automate with Cron
To update your wallpaper daily, add it to your crontab (\`crontab -e\`):
```cron
0 9 * * * /path/to/your/script/apod_wallpaper.sh
```

## How it works
1. **Scraping:** It parses the NASA APOD website for the image URL.
2. **Text Cleaning:** Extracts the "Explanation" and "Title" while stripping HTML tags.
3. **Processing:** Creates a high-quality text overlay with a semi-transparent background for readability.
4. **Setting:** Updates the KDE desktop background with the final composition.

## License
