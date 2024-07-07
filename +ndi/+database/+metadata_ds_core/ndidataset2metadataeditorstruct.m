function datasetInformation = ndidataset2metadataeditorstruct(D)
%
% DATASETINFORMATION = NDIDATASET2METADATAEDITORSTRUCT(D)
%
% Read an NDIMetaDataEditorApp data structure from the documents
% in an ndi.dataset D.
%
% Inputs:
%    D - an ndi.dataset object
%
% Outputs:
%    DATASETINFORMATION - metadata structured used by the 
%       NDIMetaDataEditorApp
%

datasetInformation = {};


  %% Dataset

dataset_version_doc = D.database_search(ndi.query('openminds.matlab_type','exact_string','openminds.core.products.DatasetVersion'));

dv_f = {};
if numel(dataset_version_doc) > 0
	datav = ndi.document.find_newest(dataset_version_doc);
	dv_f = datav.document_properties.openminds.fields;
	datasetInformation.Description{1} = dv_f.description;
	datasetInformation.DatasetFullName = dv_f.fullName;
	datasetInformation.DatasetShortName = dv_f.shortName;
	datasetInformation.ReleaseDate = datetime(dv_f.releaseDate);
	datasetInformation.VersionIdentifier = dv_f.versionIdentifier;
	datasetInformation.VersionInnovation = dv_f.versionInnovation;
else
	return;
end

 %% Process author information

author_doc = {};


for i = 1:numel(dv_f.author)
	author_id = dv_f.author{i}(7:end);
	author_doc{i} = D.database_search(ndi.query('base.id', 'exact_string', author_id));
end

for i = 1:numel(dv_f.otherContribution)
	oc_id = dv_f.otherContribution{i}(7:end);
	oc_doc{i} = D.database_search(ndi.query('base.id', 'exact_string', oc_id));
end

for i = 1:numel(dv_f.custodian)
	otherContribution_id = dv_f.custodian{i}(7:end);
	custodian_doc{i} = D.database_search(ndi.query('base.id', 'exact_string', otherContribution_id));
end

author = ndi.database.metadata_ds_core.load_author_from_ndidocument(author_doc,oc_doc, custodian_doc, D);
datasetInformation.Author = author;
dataType_name = {};
for i = 1:numel(dv_f.dataType)
	dataType_id = dv_f.dataType{i}(7:end);
	dataType_doc = D.database_search(ndi.query('base.id', 'exact_string',dataType_id));
	dataType_name{i} = dataType_doc{1}.document_properties.openminds.fields.name;
end

  %% Data types

datasetInformation.DataType = ndi.util.openminds.find_instance_name(dataType_name, 'SemanticDataType');

experimentalApproach_name = {};
for i = 1:numel(dv_f.experimentalApproach)
	experimentalApproach_id = dv_f.experimentalApproach{i}(7:end);
	experimentalApproach_doc = D.database_search(ndi.query('base.id', 'exact_string',experimentalApproach_id));
	experimentalApproach_name{i} = experimentalApproach_doc{1}.document_properties.openminds.fields.name;
end
datasetInformation.ExperimentalApproach = ndi.util.openminds.find_instance_name(experimentalApproach_name, 'ExperimentalApproach');

TechniquesEmployed = {};
for i = 1:numel(dv_f.technique)
	techniquesEmployed_id = dv_f.technique{i}(7:end);
	techniquesEmployed_doc = D.database_search(ndi.query('base.id', 'exact_string',techniquesEmployed_id));
	type = techniquesEmployed_doc{1}.document_properties.openminds.openminds_type;
	type = split(type, '/');
	type = type{end};
	name = techniquesEmployed_doc{1}.document_properties.openminds.openminds_id;
	name = split(name, '/');
	name = name{end};
	TechniquesEmployed{i} = strcat(name, ' (', type, ')');
end

datasetInformation.TechniquesEmployed = TechniquesEmployed;



