# fileReference

The `fileReference` document class records a file that exists **outside**
the database: its name, its size, its dates and its checksum. It holds no
file of its own.

## Why it is not generic_file

`generic_file` is for a file the database **holds**. Its class declares
`generic_file.ext` with `mustbenotempty: 1`, and the cloud download path
(`ndi.cloud.download.downloadGenericFiles`) exists to fetch those bytes
back out. A `generic_file` document without its file is not a lighter
version of one — it is an invalid one.

That distinction was learned the hard way. `ndi.fun.doc.gene.makeSourceFile`
used to describe a source `.gef` by creating a `generic_file` document and
deliberately not attaching the file, on the reasoning that ingesting a copy
of a 9.4 GB container beside the pyramid derived from it doubles the
storage to hold bytes the pyramid already summarises. The reasoning was
right; the class was wrong. The documents were schema-invalid from the
moment they were made, and stayed invisible only because DID's file
validation used to fail open — it fell through to "valid" when a required
file was absent (fixed in did-matlab #182). When that was tightened, every
affected session became uncopyable into a dataset, with an error naming a
file_list that was in fact perfectly correct.

So the two cases now have two classes, and the difference is in the name:

| | holds the bytes | records the identity |
| --- | --- | --- |
| `generic_file` | yes, `generic_file.ext` required | — |
| `fileReference` | no files at all | filename, size, dates, checksum |

## What identifies the file

**The checksum, not the path.** A filename tells you what somebody called
a file; a checksum tells you whether the file you have now is the file the
document was made from. Two SAW runs of the same chip produce files with
the same name and different contents, which is exactly the confusion this
is meant to survive. `originalPath` is recorded as a hint about where the
file was, not a promise about where it is — paths do not survive moving
between machines.

`checksumAlgorithm` is stored alongside the checksum so a later reader can
verify it without guessing. An empty `checksum` means *not computed*; it
never means the file was empty.

`fileSize` is a cheap second field: two files of different sizes are
certainly not the same file, and the size is readable without opening it.

## Pointing at one

`fileReference` carries the same optional `document_id` dependency
`generic_file` does, so it can name a document it is about. In the other
direction, documents point at it through their own dependencies —
`spatialGeneExpressionPyramid`, `spatialGeneExpressionTiles` and
`spatialGeneExpressionCells` all declare an optional `source_file_id`,
which may name either class. Those dependencies are untyped, so a session
built before this class existed, pointing `source_file_id` at a
`generic_file`, keeps working.

## See also

`ndi.fun.doc.gene.makeSourceFile`, which creates a `fileReference` by
default and a `generic_file` when asked to attach the file;
`ndi.cloud.download.downloadGenericFiles`, which is for the other class.
