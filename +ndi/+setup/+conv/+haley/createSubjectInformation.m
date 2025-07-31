function [subjectString, strain, species, biologicalSex] = createSubjectInformation(tableRow)
%CREATESUBJECTINFORMATION Creates subject ID string and openMINDS objects for species/strain/sex.
%
%   [subjectString, strain, species, biologicalSex] = CREATESUBJECTINFORMATION(tableRow)

% Input argument validation
arguments
    tableRow (1, :) table
end

% --- Populate Species openMINDS Object ---
species = openminds.controlledterms.Species;
species.name = 'Caenorhabditis elegans';
species.preferredOntologyIdentifier = 'NCBITaxon:6239';
species.definition = 'Caenorhabditis elegans is a species of nematode in the family Rhabditidae that is widely used as an experimental model organism.';
species.synonym = 'C. elegans';

% --- Populate Strain openMINDS Object ---
N2 = openminds.core.research.Strain;
N2.name = 'N2';
N2.species = species;
N2.ontologyIdentifier = 'WBStrain:00000001';
N2.description = 'Genotype: Caenorhabditis elegans wild isolate.';
N2.geneticStrainType = 'wild type';

if strcmp(tableRow.strain{1},'WBStrain:00000001')
    strain = N2;
else
    strain = openminds.core.research.Strain;
    [id,name,~,definition] = ndi.ontology.lookup(tableRow.strain{1});
    strain.name = name;
    strain.species = species;
    strain.ontologyIdentifier = id;
    strain.description = definition;
    strain.geneticStrainType = 'transgenic';
    strain.backgroundStrain = N2;
end

% --- Populate BiologicalSex openMINDS Object ---
biologicalSex = openminds.controlledterms.BiologicalSex;
biologicalSex.name = 'hermaphrodite';
biologicalSex.preferredOntologyIdentifier = 'PATO:0001340';

% --- Create subject string ---
expDate = char(datetime(tableRow.expTime),'yyMMdd');
subjectString = join({strain.name{1},tableRow.wormID{1},...
    tableRow.assayType{1},expDate},'_');
subjectString = [subjectString{1},'@chalasani-lab.salk.edu'];

end % End function createSubjectInformation