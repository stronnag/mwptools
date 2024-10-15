# mwp manual

* Uses `mkdocs`
  * Build navigable and searchable HTML documentation
  * Generate PDF manual

## Dependencies

As most people won't want to actually build the manual, these are not hard build requirements, but are necessary to build the manual.

* mkdocs
* mkdocs-with-pdf
* mkdocs-macros-plugin
* mkdocs-material
* probably some more ...

Trying run `mkdocs` will reveal missing packages. Most distros don't package all that is needed; you'll end up with some `pip`/`pipx` packages as well.

The HTML site can then be build with `mkdocs build` or `mkdocs serve`.

The PDF is built with `ENABLE_PDF_EXPORT=1 mkdocs build`

The PDF file is extremely large (c. 40MB), reduce to a more acceptable size ...

```
gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook \
  -dNOPAUSE -dBATCH -dColorImageResolution=150 \
    -sOutputFile=../mwptools.pdf mwptools.pdf
```

Push HTML docs to GitHub pages (maintainer):

`mkdocs gh-deploy --force`
