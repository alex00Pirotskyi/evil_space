Drop slideshow images into this directory.

Supported formats: PNG, JPG/JPEG, WebP, GIF, BMP.

The app discovers image assets from Flutter's AssetManifest at runtime, downsamples
each image to the current slideshow viewport, quantizes every pixel to RGB565,
and transitions between frames using the runway pixel effect.

File order is alphabetical. Prefix filenames with 01_, 02_, 03_, ... if you
want explicit slideshow ordering.
