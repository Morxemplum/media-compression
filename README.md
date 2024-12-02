# Archived
**This repository is now archived, as any scripts I now have are part of my [dotfiles](https://github.com/Morxemplum/dotfiles) repository.**

# Media Compression

These are a collection of shell scripts (written in Bash) that take media and compress them to lower file size without sacrificing quality (unless specified). A couple of different programs are needed to run the scripts, depending on the script

### Scripts:
- [GIF Converter](#gif-converter)
- [H.264 To AV1 Converter](#h264-to-av1-converter)
- [JPEG Converter](#jpeg-converter)
- [PNG Converter](#png-converter)

## GIF Converter
#### (Requires [ffmpeg](https://ffmpeg.org/))

The problem with GIFs go farther than its pronunciation. It is an archaic format, going all the way back to the 1980s, and has not been updated since. It has limitations such as 8-bit color palette, no alpha channels, but worst of all: egregious compression leading to extremely high file sizes. GIF was not designed for the modern internet. It is time we lay GIF to rest. 

Since GIF's primary appeal is it's animation capabilities, this script takes frames from GIFs and converts them into video frames, where it can take advantage of compression techniques from video and save a high amount of file space. For reliability purposes, it uses the H.264 codec.

### Flags

``--delete-originals``: After a GIF is successfully converted, the GIF is deleted.

``-i | --input [directory_path]``: Manually specify the input directory to scan and convert files. If not given, uses the directory the script resides in.

``-o | --output [directory_path]`` **(REQUIRED)**: Manually specify output directory for files

``-v | --overwrite``: Makes ffmpeg overwrite the files instead of skipping them

## H.264 TO AV1 Converter
#### (Requires **ffprobe** and [ffmpeg](https://ffmpeg.org/))

**You will need a powerful PC to run this script, or you will need a GPU that has AV1 hardware acceleration.** 

H.264 has been the reliable codec that the internet uses for streaming video for several years. However, with the uprising of 4K and 8K video, this quality is a lot more demanding and requires a much higher bitrate, which leads to exponentially bigger file sizes. This is very taxing on bandwidth and storage.

H.265 was meant to be the solution, but in the several years it has been out, its adoption has been poor. That's because H.265 is riddled with patents, leading to tons of complications that make even most of the big tech companies not wanting to use it. The most recent H.266 codec introduced a few years ago still suffers from the same patents, killing its potential right from the start. The AOM, which introduced the AV1 codec, an H.265 competitor that has none of the patenting issues, is garnering adoption quicker with AV1 in the few years it was out than H.265 did.

This script takes advantage of Intel's SVT version of the AV1 encoder, which has better multithreading and easier configuration than the reference encoder. This script uses ffprobe to scrape the metadata of video, getting things like bitrate, size, and fps, and uses it to calculate a new bitrate. It applies that new bitrate to the video, to where there is no noticable quality loss.

### Flags

``--delete-originals``: After a video is successfully converted, the original video is deleted.

``-i | --input [directory_path]``: Manually specify the input directory to scan and convert files. If not given, uses the directory the script resides in.

``-m | --multiplier [int]``: Multiplier of the new video from the base video (0-100). Through many different trials, I found 60 was the best compromise between no loss of quality and space savings. It can go down to 50 with some noticable loss, though I recommend you use a lower preset if you want to avoid artifacting.

``-o | --output [directory_path]`` **(REQUIRED)**: Manually specify output directory for files

``-p | --preset [int]``: Sets the preset value for the SVT-AV1 codec (0-12). By default, it is set to 8 which I consider the real time preset, and I don't recommend to go past this point otherwise you will notice horrible artifacts if bitrate is not sufficient. Presets 5 and 6 will see noticable improvements at half the encoding speed. I don't recommend preset 4 or below unless you are willing to spend a long time encoding or have hardware acceleration.

``-v | --overwrite``: Makes ffmpeg overwrite the files instead of skipping them

## JPEG Converter
#### (Requires [ImageMagick](https://imagemagick.org/index.php))

JPEG has been the go-to image format for lossy compression for the past few decades. However, JPEG's initial compression algorithms are starting to see better days. They were not designed for high quality images and don't do a great job of preserving the quality of the image.  There have been many attempts to try and improve upon JPEG to have better compression algorithms that not only compress more, but also preserve image quality, but none of them really caught on. 

There are two contenders for what is to become the new lossy image format: AVIF and JPEG-XL. AVIF takes a lot of the algorithms from the AV1 encoder and brings them to images, competing with HEIC. With AVIF, you can get stunningly low file sizes while having good image quality. However, JPEG-XL is JPEG's newest attempt at improving JPEG. JPEG-XL was designed with the internet in mind, bringing useful features, such as progressive decoding (which is seriously cool), alpha channels, but most importantly: lossless conversion with legacy JPEG. However, JPEG-XL is still bleeding edge, leading to AVIF having better support for browsers (though this may change in the near future).

This script lets you choose to convert to AVIF or JPEG-XL. JPEG-XL is the default because of the lossless conversion, but if having low file sizes or quickly sending something on the internet is your priority, you'll want to choose AVIF. 

### Flags

``--delete-originals``: After a video is successfully converted, the original video is deleted.

``-f | --format <avif, jxl>``: Specify the output's image format. Again, both are good for lossy images, and you'll want to choose one depending on your use case.

``-i | --input [directory_path]``: Manually specify the input directory to scan and convert files. If not given, uses the directory the script resides in.

``-o | --output [directory_path]`` **(REQUIRED)**: Manually specify output directory for files

``-q | --quality [int]``: If you chose the AVIF format, you can determine the quality of the converted image (1-100). Like with the AV1 script, 60 is a good compromise between no quality loss and good compression.

``-s | --strip``: If there is any metadata attached to the image, it will remove it. This is useful if you want to cut corners and save space.

``-v | --overwrite``: Overwrites the files instead of skipping them

## PNG Converter
#### (Requires [ImageMagick](https://imagemagick.org/index.php))

For the 90s, PNG was ahead of its time. Alpha channels, 24-bit color support, and lossless compression. It could've killed off GIF if GIF didn't get a cult status. However, because it prides itself on lossless compression, it isn't able to save as much space as a lossy format can. This quickly compounds when you increase the resolution of the image. However, because JPEG didn't support alpha channels, PNG was your only shot of having transparency in your images.

In the 2010s, Google created the WebP format, which was meant to improve on JPEG, PNG, and GIF. It does great in lossy compression -- though AVIF certainly beats it out with quality preservation -- but it does best in its lossless compression, where the algorithms generally perform better than PNG. In the past few years, it is garnering adoption in the web (seriously, try looking up an image in Google Images and see how long it takes to find a webp image), beginning the new generation of image formats.

This script takes PNGs and converts them to WebP's lossless mode, preserving all quality when converting.

### Flags

``--delete-originals``: After a video is successfully converted, the original video is deleted.

``-i | --input [directory_path]``: Manually specify the input directory to scan and convert files. If not given, uses the directory the script resides in.

``-o | --output [directory_path]`` **(REQUIRED)**: Manually specify output directory for files.

``-s | --strip``: If there is any metadata attached to the image, it will remove it. This is useful if you want to cut corners and save space.

``-v | --overwrite``: Overwrites the files instead of skipping them.
