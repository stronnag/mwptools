## Geozone Reader

Reads (CLI `diff` / `dump`) file containing `geozone` stanzas and generated a KML.

## Usage

```
geozones [options] zonefile
  -name string
    	name (default "Unknown")
  -show-points
    	show points in output
  -output string
    	output file name ('-' => stdout) (default "-")
  -use-polyline
    	show polylines (vice polygons)
  -verbose
    	dump out geozone structures
```

If `zonefile` is `-`, then data is read from `stdin` (i.e. for use in pipelines).
