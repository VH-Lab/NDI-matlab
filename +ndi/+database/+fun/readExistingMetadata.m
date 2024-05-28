function datasetInformation = readExistingMetadata(D)
%READEXISTINGMETADATA - retrieves metadata from an existing dataset
%   
% DATASETINFORMATION = ndi.database.fun.READEXISTINGMETADATA(D)
%
% Inputs:
%   D - the ndi.dataset object
%
% Outputs:
%   DATASETINFORMATION - the metadata structure
datasetInformation = struct();
dataset_doc = {};
d_f = '';
dataset_version_doc = {};
dv_f= '';
author_doc_id = {};
author_doc = {};
dataType_id = {};
studiedSpecimen_id = {};
experimentalApproach_id = {};
license_id = {};
otherContribution_id = {};
otherContribution_doc = {};
funding_id = {};
relatedPublication_id = {};
relatedPublication = {};

% d_openminds_docs = D.database_search(ndi.query('','isa','openminds'));
dataset_version_doc = D.database_search(ndi.query('openminds.matlab_type','exact_string','openminds.core.products.DatasetVersion'));
dv_f = {};
if numel(dataset_version_doc) > 0
    dv_f = dataset_version_doc{1, 1}.document_properties.openminds.fields;
    datasetInformation.Description{1} = dv_f.description;
    datasetInformation.DatasetFullName = dv_f.fullName;
    datasetInformation.DatasetShortName = dv_f.shortName;
    datasetInformation.ReleaseDate = datetime(dv_f.releaseDate);
    datasetInformation.VersionIdentifier = dv_f.versionIdentifier;
    datasetInformation.VersionInnovation = dv_f.versionInnovation;
    author_doc_id = dv_f.author;
    dataType_id = dv_f.dataType;
    experimentalApproach_id = dv_f.experimentalApproach;
    TechniquesEmployed_id = dv_f.technique;
    funding_id = dv_f.funding;
    studiedSpecimen_id = dv_f.studiedSpecimen;
    license_id = dv_f.license;
    otherContribution_id = dv_f.otherContribution;
    otherContribution_id = dv_f.custodian;
    relatedPublication_id = dv_f.relatedPublication;
end

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

author = ndi.cloud.fun.load_author_from_cloud(author_doc,oc_doc, custodian_doc, D);
datasetInformation.Author = author;
dataType_name = {};
for i = 1:numel(dv_f.dataType)
    dataType_id = dv_f.dataType{i}(7:end);
    dataType_doc = D.database_search(ndi.query('base.id', 'exact_string',dataType_id));
    dataType_name{i} = dataType_doc{1}.document_properties.openminds.fields.name;
end
datasetInformation.DataType = ndi.cloud.fun.find_instance_name(dataType_name, 'SemanticDataType');

experimentalApproach_name = {};
for i = 1:numel(dv_f.experimentalApproach)
    experimentalApproach_id = dv_f.experimentalApproach{i}(7:end);
    experimentalApproach_doc = D.database_search(ndi.query('base.id', 'exact_string',experimentalApproach_id));
    experimentalApproach_name{i} = experimentalApproach_doc{1}.document_properties.openminds.fields.name;
end
datasetInformation.ExperimentalApproach = ndi.cloud.fun.find_instance_name(experimentalApproach_name, 'ExperimentalApproach');

techniquesEmployed_name = {};
for i = 1:numel(dv_f.technique)
    techniquesEmployed_id = dv_f.technique{i}(7:end);
    techniquesEmployed_doc = D.database_search(ndi.query('base.id', 'exact_string',techniquesEmployed_id));
    techniquesEmployed_name{i} = techniquesEmployed_doc{1}.document_properties.openminds.fields.name;
end
datasetInformation.TechniquesEmployed = ndi.cloud.fun.find_instance_name(TechniquesEmployed_name, 'TechniquesEmployed');

funding = struct();
for i = 1:numel(dv_f.funding)
    funding_id = dv_f.funding{i}(7:end);
    funding_doc = D.database_search(ndi.query('base.id', 'exact_string',funding_id));
    funding.awardTitle = funding_doc{1}.openminds.fields.awardTitle;
    funding.awardNumber = funding_doc{1}.openminds.fields.awardNumber;
    funder_id =funding_doc{1}.document_properties.openminds.fields.funder{1}(7:end);
    funder_doc = D.database_search(ndi.query('base.id', 'exact_string',funder_id));
    funding.funder = funder_doc{1, 1}.document_properties.openminds.fields.fullName;
end
datasetInformation.Funding = funding;

Subjects = {};
for i = 1:numel(dv_f.studiedSpecimen)
    Subjects{i} = struct();
    studiedSpecimen_id = dv_f.studiedSpecimen{i}(7:end);
    studiedSpecimen_doc = D.database_search(ndi.query('base.id', 'exact_string',studiedSpecimen_id));
    Subjects{i}.SubjectNameList = studiedSpecimen_doc{1}.document_properties.openminds.fields.lookupLabel;
    species_id = studiedSpecimen_doc{1}.document_properties.openminds.fields.species{1}(7:end);
    species_doc = D.database_search(ndi.query('base.id', 'exact_string',species_id));
    openminds_species_id = species_doc{1}.document_properties.openminds.fields.species{1}(7:end);
    openminds_species_doc = D.database_search(ndi.query('base.id', 'exact_string',openminds_species_id));
    %create species object using Species(name, ontologyIdentifier, synonym)
    Subjects{i}.SpeciesList = ndi.database.metadata_app.class.Species(...
    openminds_species_doc{1}.document_properties.openminds.fields.name, ...
    openminds_species_doc{1}.document_properties.openminds.fields.preferredOntologyIdentifier, ...
    openminds_species_doc{1}.document_properties.openminds.fields.synonym);
    studiedSpecimen_doc{1}.document_properties.openminds.fields.species;
end
end


