# NDI Document Tips

This document describes conventions and best practices for storing common data types in NDI documents.

## Epochnodes

Epoch nodes (often referred to as `epochnode` in code and schemas) are structures that represent a specific epoch within a DAQ system or session. They are used to identify and link data segments across different systems or time references.

### MATLAB Data Type

In MATLAB, an epoch node is represented as a `struct` with the following fields:

*   `epoch_id`: (string) The unique identifier of the epoch.
*   `epoch_session_id`: (string) The ID of the session the epoch belongs to.
*   `epochprobemap`: (string) A serialized representation of the epoch probe map.
*   `epoch_clock`: (string) A serialized representation of the epoch clock type (e.g., produced by `ndi_clocktype2char`).
*   `t0_t1`: (double array) The start and end time of the epoch.
*   `objectname`: (string) The name of the object (e.g., DAQ system name).
*   `objectclass`: (string) The class of the object.
*   `underlying_epochs`: (struct) A structure containing information about underlying epochs.

### Storage in Documents

When storing epoch nodes in NDI database documents (such as `syncrule_mapping`), the data is stored as a generic `structure` type.

**Important Storage Convention:**
While the in-memory MATLAB structure includes `underlying_epochs`, this field is **not** stored in the database document. `underlying_epochs` often contains complex structures with custom object types that are not suitable for direct serialization into the document schema.

Therefore, the stored structure typically contains only:
*   `epoch_id`
*   `epoch_session_id`
*   `epochprobemap`
*   `epoch_clock`
*   `t0_t1`
*   `objectname`
*   `objectclass`

### Examples

Epoch nodes are stored in the following document types:

*   **`syncrule_mapping`**: Used to store the relationship between two epochs in a synchronization graph.
    *   Fields: `epochnode_a`, `epochnode_b`
