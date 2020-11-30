# ndi.database.fun.readGenBankNames

  NDI_READGENBANKNAMES - read the GenBank names from the 'names.dmp' file
 
  GENBANK_NAMES = ndi.database.fun.readGenBankNames(FILENAME)
 
  Given a 'names.dmp' file from a GenBank taxonomy data dump,
  this function produces a Matlab structure with the following fields:
  
  fieldname            | Description
  -----------------------------------------------------------------
  genbank_commonname   | The genbank common name of the organism
                       |   (cell array of strings, 1 entry per node)
                       |   genbank_commonname{i} is the entry for node i.
  scientific_name      | The genbank scientific name
                       |   (cell array of strings, 1 entry per node)
                       |   scientific_name{i} is the entry for node i.
  synonym              | A cell array of strings with scientific name synonyms
                       |   (cell array of strings, potentially many entries per node)
                       |   synonym{i}{j} is the jth synonym for node i
  other_commonname     | A cell array of strings with the other common names
                       |   (cell array of strings, potentially many entries per node)
                       |   other_commonname{i}{j} is the jth other common name for node i
