function datasetInformation = load_metadata_from_cloud(openminds_documents)
%LOAD_METADATA_FROM_CLOUD reformat the openminds documents to a struct that can be loaded to the metadata app
%
% DATASETINFORMATION = ndi.cloud.fun.LOAD_METADATA_FROM_CLOUD(OPENMINDS_DOCUMENTS)
%
% Input:
%   OPENMINDS_DOCUMENTS: a cell array of openminds documents
%
% Output:
%   DATASETINFORMATION: a struct ready to be loaded to the metadata app

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
custodian_id = {};
funding_id = {};
relatedPublication_id = {};
relatedPublication = {};

for i = 1:numel(openminds_documents)
    if strcmp(openminds_documents{i}.openminds.matlab_type, 'openminds.core.products.Dataset')
        dataset_doc{1} = openminds_documents{i};
        d_f = dataset_doc{1, 1}.openminds.fields;
        break
    end
end

for i = 1:numel(openminds_documents)
    if strcmp(openminds_documents{i}.openminds.matlab_type, 'openminds.core.products.DatasetVersion')
        dataset_version_doc{1} = openminds_documents{i};
        dv_f = dataset_version_doc{1, 1}.openminds.fields;
        break
    end
end

if numel(dataset_version_doc) > 0
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
    custodian_id = dv_f.custodian;
    relatedPublication_id = dv_f.relatedPublication;
end

for i = 1:numel(author_doc_id)
    for j = 1:numel(openminds_documents)
        if contains(author_doc_id{i},openminds_documents{j}.base.id)
            author_doc{i} = openminds_documents{j};
            break
        end
    end
end

for i = 1:numel(otherContribution_id)
    otherContribution_docs{i} = ndi.cloud.fun.search_id(otherContribution_id{i},openminds_documents);
end

for i = 1:numel(custodian_id)
    custodian_docs{i} = ndi.cloud.fun.search_id(custodian_id{i},openminds_documents);
end

author = ndi.cloud.fun.load_author_from_cloud(author_doc,otherContribution_docs, custodian_docs, openminds_documents);
datasetInformation.Author = author;
for i = 1:numel(dataType_id)
    dataType = ndi.cloud.fun.search_id(dataType_id{i},openminds_documents);
    dataType_name{i} = dataType.openminds.fields.name;
end
% datasetInformation.DataType = ndi.cloud.fun.load_dataType_from_cloud(dataType_name);
datasetInformation.DataType = ndi.cloud.fun.find_instance_name(dataType_name, 'SemanticDataType');

for i = 1:numel(experimentalApproach_id)
    experimentalApproach = ndi.cloud.fun.search_id(experimentalApproach_id{i},openminds_documents);
    experimentalApproach_name{i} = experimentalApproach.openminds.fields.name;
end
datasetInformation.ExperimentalApproach = ndi.cloud.fun.find_instance_name(experimentalApproach_name, 'ExperimentalApproach');

for i = 1:numel(TechniquesEmployed_id)
    TechniquesEmployed = ndi.cloud.fun.search_id(TechniquesEmployed_id{i},openminds_documents);
    TechniquesEmployed_name{i} = TechniquesEmployed.openminds.fields.name;
end
datasetInformation.TechniquesEmployed = ndi.cloud.fun.find_instance_name(TechniquesEmployed_name, 'TechniquesEmployed');

for i = 1:numel(funding_id)
    funding_doc = ndi.cloud.fun.search_id(funding_id{i},openminds_documents);
    funding.awardTitle = funding_doc.openminds.fields.awardTitle;
    funding.awardNumber = funding_doc.openminds.fields.awardNumber;
    funder_doc = ndi.cloud.fun.search_id(funding_doc.openminds.fields.funder{1},openminds_documents);
    funding.funder = funder_doc.openminds.fields.fullName;
end
datasetInformation.Funding = funding;
studiedSpecimen_doc = {};
for i = 1:numel(studiedSpecimen_id)
    studiedSpecimen_doc = ndi.cloud.fun.search_id(studiedSpecimen_id{i},openminds_documents);
end

[license_names, license_short_names] = ndi.database.metadata_app.fun.getCCByLicences();
short_name_to_names = containers.Map(license_short_names, license_names);

for i = 1:numel(license_id)
    license_doc = ndi.cloud.fun.search_id(license_id{i},openminds_documents);
    datasetInformation.License = short_name_to_names(license_doc.openminds.fields.shortName);
end

for i = 1:numel(relatedPublication_id)
    for j = 1:numel(openminds_documents)
        if contains(relatedPublication_id{i},openminds_documents{j}.base.id)
            relatedPublication{i} = openminds_documents{j};
            break
        end
    end
end
