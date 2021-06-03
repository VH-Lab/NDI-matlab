# ndi.database.fun.createNIFbrainareas

```
  NDI_CREATENIFBRAINAREAS - create a list of allowable brain areas from the NIF-Ontology
 
  BA = ndi.database.fun.createNIFbrainareas(...)
 
  Creates a list of 'controlled' brain area labels and the corresponding nodes in the NIF-Ontology.
 
  Traces all areas that make up a part of the UBERON node 'nervous system', excluding those in the
  first level of depth (which are all relatively vague descriptors). This is then written to a file
  'NIFBrainAreaControlledVocabulary.tsv' with a string id that describes the NIF-Ontology node ID
  and a string lbl that describes the NIF-Ontology label:
 
  Header row:
    'ID<tab>LABEL<tab>Synonyms<tab><Other_Common_Name'
    and then 1 entry per anatomical node.
 
  This function also takes name/value pairs that modify the behavior.
  Parameter (default)     | Description
  ---------------------------------------------------------------------------
  root ('UBERON:'...      | Root node for establishing the controlled vocabulary.
   '0001016')             |  (Default is 'nervous system' in Uberon ontology.)
  depth (1000)            | How deep past "nervous system" to look
  depth_exclude (1)       | The depths to exclude from the list
  exclude_ontologies ({...| Ontologies to exclude
   'CL'})                 |
  outname (...            | Output filen name of the file written to disk
  ['NIFBrainAreaContr'... |
   'olledVocabulary.tsv'])|

```
