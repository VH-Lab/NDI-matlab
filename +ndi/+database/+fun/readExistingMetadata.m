function datasetInformation = readExistingMetadata(D, entries)
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
    type = techniquesEmployed_doc{1}.document_properties.openminds.openminds_type;
    type = split(type, '/');
    type = type{end};
    name = techniquesEmployed_doc{1}.document_properties.openminds.openminds_id;
    name = split(name, '/');
    name = name{end};
    techniquesEmployed_name{i} = strcat(type, ' (', name, ')');
end
datasetInformation.TechniquesEmployed = techniquesEmployed_name;

funding = struct();
for i = 1:numel(dv_f.funding)
    funding_id = dv_f.funding{i}(7:end);
    funding_doc = D.database_search(ndi.query('base.id', 'exact_string',funding_id));
    funding.awardTitle = funding_doc{1}.document_properties.openminds.fields.awardTitle;
    funding.awardNumber = funding_doc{1}.document_properties.openminds.fields.awardNumber;
    funder_id =funding_doc{1}.document_properties.openminds.fields.funder{1}(7:end);
    funder_doc = D.database_search(ndi.query('base.id', 'exact_string',funder_id));
    funding.funder = funder_doc{1, 1}.document_properties.openminds.fields.fullName;
end
datasetInformation.Funding = funding;

Subjects = ndi.database.metadata_app.class.Subject.empty();
for i = 1:numel(dv_f.studiedSpecimen)
    subject = struct();
    studiedSpecimen_id = dv_f.studiedSpecimen{i}(7:end);
    studiedSpecimen_doc = D.database_search(ndi.query('base.id', 'exact_string',studiedSpecimen_id));
    subject.SubjectName = studiedSpecimen_doc{1}.document_properties.openminds.fields.lookupLabel;
    biologicalSex_id = studiedSpecimen_doc{1}.document_properties.openminds.fields.biologicalSex{1}(7:end);
    biologicalSex_doc = D.database_search(ndi.query('base.id', 'exact_string',biologicalSex_id));
    subject.BiologicalSexList = {biologicalSex_doc{1}.document_properties.openminds.fields.name};
    species_id = studiedSpecimen_doc{1}.document_properties.openminds.fields.species{1}(7:end);
    species_doc = D.database_search(ndi.query('base.id', 'exact_string',species_id));
    openminds_species_id = species_doc{1}.document_properties.openminds.fields.species{1}(7:end);
    openminds_species_doc = D.database_search(ndi.query('base.id', 'exact_string',openminds_species_id));
    %create species object using Species(name, ontologyIdentifier, synonym)
    subject.SpeciesList = ndi.database.metadata_app.class.Species(...
    openminds_species_doc{1}.document_properties.openminds.fields.name, ...
    openminds_species_doc{1}.document_properties.openminds.fields.preferredOntologyIdentifier, ...
    openminds_species_doc{1}.document_properties.openminds.fields.synonym);
    subject.sessionIdentifier = studiedSpecimen_doc{1}.document_properties.base.session_id;
    Subjects(i) = ndi.database.metadata_app.class.Subject();
    Subjects(i).SubjectName = subject.SubjectName;
    Subjects(i).BiologicalSexList = subject.BiologicalSexList;
    Subjects(i).SpeciesList = subject.SpeciesList;
    Subjects(i).sessionIdentifier = subject.sessionIdentifier;
end
datasetInformation.Subjects = Subjects;
strainInstances = loadStrain(D, entries);
end

function strainInstances = loadStrain(D,entries)
    import ndi.database.metadata_app.fun.loadUserInstanceCatalog
    strainInstances = loadUserInstanceCatalog('Strain');
    strain_docs = D.database_search(ndi.query('openminds.openminds_type', 'exact_string','https://openminds.ebrains.eu/core/Strain'));
    for i = 1:numel(strain_docs)
        strain_doc = strain_docs{i};
        strain = struct();
        strain.name = strain_doc.document_properties.openminds.fields.name;
        strain.species = readOpenmindsId(D, strain_doc, 'species');
        strain.geneticStrainType = readOpenmindsId(D, strain_doc, 'geneticStrainType');
        strain.phenotype = strain_doc.document_properties.openminds.fields.phenotype;
        strain.breedingType = readOpenmindsId(D, strain_doc, 'breedingType');
        for j = 1:numel(strain_doc.document_properties.openminds.fields.backgroundStrain)
            strain.backgroundStrain{j} = readName(D, strain_doc, 'backgroundStrain');
        end
        strain.laboratoryCode = strain_doc.document_properties.openminds.fields.laboratoryCode;
        strain.stockNumber = readOpenmindsId(D, strain_doc, 'stockNumber');
        strain.digitalIdentifier = readOpenmindsId(D, strain_doc, 'digitalIdentifier');
        strain.alternateIdentifier = strain_doc.document_properties.openminds.fields.alternateIdentifier;
        strain.ontologyIdentifier = strain_doc.document_properties.openminds.fields.ontologyIdentifier;
        strain.synonym = strain_doc.document_properties.openminds.fields.synonym;
        strain.description = strain_doc.document_properties.openminds.fields.description;
        strain.diseaseModel = readOpenmindsId(D, strain_doc, 'diseaseModel');
        try
            strainInstances.add(strain)
            strainInstances.save()
        catch ME
            if ME.identifier == "Catalog:NamedItemExists"
                disp("Strain already exists in the catalog. Do you want to update it?");
                prompt = 'Y/N [Y]: ';
                str = input(prompt,'s');
                if isempty(str)
                    str = 'Y';
                end
                if str == 'Y'
                    strainInstances.update(strain)
                    strainInstances.save()
                else
                    disp("Aborted");
                end
            else
                disp("Aborted");
            end
        end
        
    end
end

function property = readOpenmindsId(D, doc, name)
    if ~isempty(doc.document_properties.openminds.fields.(name))
        property_doc = D.database_search(ndi.query('base.id', 'exact_string', doc.document_properties.openminds.fields.(name){1}(7:end)));
        property = property_doc{1}.document_properties.openminds.openminds_id;
    else
        property = [];
    end
end

function property = readName(D, doc, name)
    if ~isempty(doc.document_properties.openminds.fields.(name))
        property_doc = D.database_search(ndi.query('base.id', 'exact_string', doc.document_properties.openminds.fields.(name){1}(7:end)));
        property = property_doc{1}.document_properties.openminds.fields.name;
    else
        property = [];
    end
end


