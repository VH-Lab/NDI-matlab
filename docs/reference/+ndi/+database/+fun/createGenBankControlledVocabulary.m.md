# ndi.database.fun.createGenBankControlledVocabulary

```
  NDI_CREATEGENBANKCONTROLLEDVOCABULARY - create the controlled vocabulary dictionary for animals
  
  ndi.database.fun.createGenBankControlledVocabulary(DIRNAME, ...)
 
  This function examines the name file 'names.dmp' and node file 'nodes.dmp' from 
  the GenBank taxonomy database in the directory DIRNAME. It generates a new text file
  called 'GenBankControlledVocabulary.tsv' with the following structure:
 
  Header row:
    'Scientific_Name<tab>GenBank_Common_Name<tab>Synonyms<tab><Other_Common_Name'
    and then 1 entry per organism.
 
  This function also takes name/value pairs that modify the behavior.
  Parameter (default)     | Description
  ---------------------------------------------------------------------------
  root_node ('Bilateria') | Root scientific name to start with; usually 'Bilateria' to
                          |  include most research organisms but not cell lines, 
                          |  bacteria, viruses, etc (everything not 'Bilateria').
                          |  Use 'Root' for everything.
  nodefile ('nodes.dmp')  | File name of the node file within DIRNAME
  namefile ('names.dmp')  | File name of the name file with DIRNAME
  outname (...            | Output filen name of the file written to disk
  ['GenBankControlled'... | 
    'Vocabulary.tsv'])
 
  The taxonomy data is available at https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz.
 
  This function usually takes a couple of hours to run and shows 3 progress bars
  (the first one is faster than the second).

```
