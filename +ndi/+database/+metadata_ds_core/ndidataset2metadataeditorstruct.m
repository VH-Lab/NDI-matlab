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

    Funding = struct();
    for i = 1:numel(dv_f.funding)
        funding_id = dv_f.funding{i}(7:end);
        funding_doc = D.database_search(ndi.query('base.id', 'exact_string',funding_id));
        funder_id =funding_doc{1}.document_properties.openminds.fields.funder{1}(7:end);
        funder_doc = D.database_search(ndi.query('base.id', 'exact_string',funder_id));
        Funding(i).funder = funder_doc{1, 1}.document_properties.openminds.fields.fullName;
        Funding(i).awardTitle = funding_doc{1}.document_properties.openminds.fields.awardTitle;
        Funding(i).awardNumber = funding_doc{1}.document_properties.openminds.fields.awardNumber;
    end
    datasetInformation.Funding = Funding;

    FullDocumentation = '';
    for i = 1:numel(dv_f.fullDocumentation)
        fullDocumentation_id = dv_f.fullDocumentation{i}(7:end);
        fullDocumentation_doc = D.database_search(ndi.query('base.id', 'exact_string',fullDocumentation_id));
        FullDocumentation = fullDocumentation_doc{1, 1}.document_properties.openminds.fields.IRI;
    end
    datasetInformation.FullDocumentation = FullDocumentation;

    Subjects = ndi.database.metadata_app.class.Subject.empty();
    strainInstances = loadStrain(D);
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
        %openminds_species_id = species_doc{1}.document_properties.openminds.fields.species{1}(7:end);
        %openminds_species_doc = D.database_search(ndi.query('base.id', 'exact_string',openminds_species_id));
        
        subject.SpeciesList = ndi.database.metadata_app.class.Species(...
           species_doc{1}.document_properties.openminds.fields.name, ...
           species_doc{1}.document_properties.openminds.fields.preferredOntologyIdentifier, ...
           species_doc{1}.document_properties.openminds.fields.synonym);
        subject.sessionIdentifier = studiedSpecimen_doc{1}.document_properties.base.session_id;
        Subjects(i) = ndi.database.metadata_app.class.Subject();
        Subjects(i).SubjectName = subject.SubjectName;
        Subjects(i).BiologicalSexList = subject.BiologicalSexList;
        Subjects(i).SpeciesList = subject.SpeciesList;
        Subjects(i).sessionIdentifier = subject.sessionIdentifier;
        Subjects(i).StrainList = ndi.database.metadata_app.class.Strain(species_doc{1, 1}.document_properties.openminds.fields.name);
    end
    datasetInformation.Subjects = Subjects;

    License = '';
    if ~isempty(dv_f.license)
        license_id = dv_f.license{1}(7:end);
        license_doc = D.database_search(ndi.query('base.id', 'exact_string',license_id));
        
        webpage = license_doc{1, 1}.document_properties.openminds.fields.webpage{2};
        %remove the last item after . from the end of the webpage, but keep all the other items. Might have multiple . in the url
        webpage = split(webpage, '.');
        webpage = webpage(1:end-1);
        webpage = strjoin(webpage, '.');
        
        License = split(webpage, '/');
        License = License{end};
    end
    datasetInformation.License = strrep(License, '"', '');

    RelatedPublication = struct();
    for i = 1:numel(dv_f.relatedPublication)
        relatedPublication_id = dv_f.relatedPublication{i}(7:end);
        relatedPublication_doc = D.database_search(ndi.query('base.id', 'exact_string',relatedPublication_id));
        doi = relatedPublication_doc{1, 1}.document_properties.openminds.fields.identifier;
        publicationInfo = ndi.database.metadata_app.fun.resolveRelatedPublication(doi);
        RelatedPublication.Publication = publicationInfo.title;
        RelatedPublication.DOI = char(publicationInfo.doi);
        RelatedPublication.PMID = publicationInfo.pmid;
        RelatedPublication.PMCID = publicationInfo.pmcid;
    end
    datasetInformation.RelatedPublication = RelatedPublication;

end

function strainInstances = loadStrain(D)
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
        if numel(strain_doc.document_properties.openminds.fields.backgroundStrain) == 0
            strain.backgroundStrain = [];
        else
            for j = 1:numel(strain_doc.document_properties.openminds.fields.backgroundStrain)
                strain.backgroundStrain{j} = readName(D, strain_doc, 'backgroundStrain');
            end
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
                disp("Strain already exists in the catalog.");
            %     prompt = 'Y/N [Y]: ';
            %     str = input(prompt,'s');
            %     if isempty(str)
            %         str = 'Y';
            %     end
            %     if str == 'Y'
            %         strainInstances.update(strain)
            %         strainInstances.save()
            %     else
            %         disp("Aborted");
            %     end
            % else
            %     disp("Aborted");
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
        property = property_doc{1}.document_properties.openminds.fields.(name);
    else
        property = [];
    end
end



