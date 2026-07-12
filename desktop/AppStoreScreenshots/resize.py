import os
from PIL import Image, ImageOps
import glob

input_dir = "/Users/simo/Developer/mattioli.OS/desktop/AppStoreScreenshots"
output_dir = "/Users/simo/Developer/mattioli.OS/desktop/AppStoreScreenshots/resized"

os.makedirs(output_dir, exist_ok=True)

target_size = (1440, 900)

for file_path in glob.glob(os.path.join(input_dir, "*.png")):
    filename = os.path.basename(file_path)
    try:
        img = Image.open(file_path)
        # Convert to RGB if it's RGBA and saving to a format that doesn't support alpha, 
        # but PNG supports alpha. We keep it as is.
        # ImageOps.fit crops the image to the exact aspect ratio from the center and resizes.
        img_resized = ImageOps.fit(img, target_size, method=Image.Resampling.LANCZOS)
        output_path = os.path.join(output_dir, filename)
        img_resized.save(output_path, format="PNG")
        print(f"Resized and cropped: {filename}")
    except Exception as e:
        print(f"Error processing {filename}: {e}")

print("Done!")
