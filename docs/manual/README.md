# mwp manual

* Uses `mkdocs`
  * Build navigable HTML documentation
  * Generate PDF manual

## Dependencies

As most people won't want to actually build the manaul, these are not hard build requirements, but are necessary to build the manual.

* mkdocs
* mkdocs-with-pdf
* mkdocs-macros-plugin
* mkdocs-material

Most distros don't package all of these; you'll end up with `pip` packages as well.

Note that due to `mkdocs-with-pdf`, it is necessary to pin `mkdocs-material` at `7.3.6`

The html site can then be build with `mkdocs build` or `mkdocs serve`.

The PDF is built with `ENABLE_PDF_EXPORT=1 mkdocs build`

Push html docs to github pages (maintainer):

`mkdocs gh-deploy --force`
