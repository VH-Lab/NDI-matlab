function D = openminds_to_metadata()
%OPENMINDS_TO_METADATA Summary of this function goes here
%   Detailed explanation goes here

ndi.globals;
dirname = [ndi_globals.path.exampleexperpath filesep '..' filesep 'example_datasets' filesep 'sample_test'];

D = ndi.dataset.dir(dirname);
D = ndi.cloud.delete_local_openminds_doc(D);
metadatafile = [ndi_globals.path.exampleexperpath filesep '..' filesep 'example_datasets' filesep 'NDIDatasetUpload' filesep 'strain.mat'];
metadata = load(metadatafile);
datasetInformation = metadata.datasetInfo;
convertedDocs = ndi.database.metadata_app.convertFormDataToDocuments(datasetInformation, D.id);
D = D.database_add(convertedDocs);

end

