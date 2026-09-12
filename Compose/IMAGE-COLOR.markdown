# Portable artwork

New Compose prayer packs store the optional Gallery cover as `images/default.jpg`.
Uploaded step images use `images/<UUIDv7>.jpg`; their separate `fileId` persists in
projects and autosaves and is preserved when reopening a pack. Existing projects
receive an identity when first loaded. UUIDs follow [RFC 9562, section 5.7](https://www.rfc-editor.org/rfc/rfc9562.html#section-5.7),
with a 48-bit millisecond timestamp and 74 random bits. Shared built-in artwork
keeps its canonical keys. If the same artwork is a cover and a step image, the
pack contains both entries so a step never refers to the pack-scoped `default` key.
Replacing an image with different bytes, including legacy color normalization,
assigns a fresh filename while retaining its editor identity. This keeps a changed
copy of a devotion from replacing the artwork of another installed pack through
the native shared image pool. Unchanged images keep their filenames on re-export.

Uploads and imported legacy artwork are decoded with browser color management
enabled, drawn into an opaque white `srgb`, `unorm8` Canvas 2D context, and encoded
as an 8-bit, three-component JPEG. The [HTML Canvas specification](https://html.spec.whatwg.org/multipage/canvas.html)
defines drawing into the context's color space. Gamut conversion and SDR range
clamping happen before encoding; the browser controls HDR tone mapping, so its
highlight rendering can vary by engine. Compose does not disable color conversion
or request an HDR canvas. The [ColorWeb HDR overview](https://github.com/w3c-cg/ColorWeb-CG/blob/main/hdr-big-picture.md)
describes that browser conversion boundary.

The freshly encoded JPEG then receives an explicit sRGB ICC profile. The metadata
pass removes other application markers, comments, EXIF, XMP, and appended images
including gain maps. It checks the image precision and component count; it does
not convert arbitrary original bytes by changing their tags. Packing refuses
images that have not passed this conversion. Gallery covers retain their aspect
ratio, and legacy image normalization preserves framing while limiting the
longest edge to 2,048 pixels.
Existing archives and canonical built-in files are never rewritten in place.

`src/format/srgbProfile.ts` embeds the unmodified International Color Consortium
[sRGB2014.icc](https://registry.color.org/rgb-registry/profiles/sRGB2014.icc), the
ICC v2 sRGB profile revised in February 2015 and described on the
[ICC sRGB profiles page](https://registry.color.org/rgb-registry/srgbprofiles).
It contains the copyright tag “Copyright International Color Consortium, 2015”.
Its 3,024 bytes have SHA-256
`384b832de3412066743b52a75ee906b6fb9fb8d9e09e936fc2c43223815c6e0a`.
The [ICC profile license](https://registry.color.org/profile-library/#licensing)
permits copying, distribution, embedding, use and sale without restriction;
modified profiles must remove original identification and copyright information
and must not be presented as the original. Compose embeds this profile unchanged.

`scripts/galleryCoverTests.ts` checks profile integrity, forbidden metadata,
8-bit output, identity migration, cover/step isolation, and project, autosave,
pack and repository round trips. Browser verification also checks actual Canvas
output; mocked canvas tests alone cannot establish color conversion.
