# jrclust_clusters (ndi.document class)

## Class definition

**Class name**: [jrclust_clusters](jrclust_clusters.md)<br>
**Superclasses**: [ndi_document](../../ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/apps/JRCLUST/jrclust_clusters.json](jrclust_clusters.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/apps/JRCLUST/jrclust_clusters.json](jrclust_clusters.json)<br>
**Property_list_name**: `jrclust_clusters`<br>
**Class_version**: `1`<br>

## [jrclust_clusters](jrclust_clusters.md) fields:

Accessed by `jrclust_clusters.field` where *field* is one of the field names below

| field | default value | data type | description
| -- | -- | -- | --| 
|res_mat_MD5_checksum| N/A | HEX string | An MD5 checksum value of the JRCLUST 'res.mat' file that indicates its latest version

## [ndi_document](ndi_document.md) fields:

Accessed by `ndi_document.field` where *field* is one of the field names below

| field | default value | data type | description
| -- | -- | -- | --| 
|id| - | NDI ID string | The globally unique identifier of this document
|session_id| - | NDI ID string | The globally unique identifier of any data session that produced this document
|name| "" | character array (ASCII) | A user-specified name, free for users/developers to use as they like
|datestamp| (current time) | ISO-8601 date string, time zone must be UTC leap seconds | Time of document creation
| document_version | - | character array (ASCII) | Version of this document in the database

