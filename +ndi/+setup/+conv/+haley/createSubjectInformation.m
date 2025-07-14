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
[id,name,~,definition] = ndi.ontology.lookup('WBStrain:N2');
N2.name = name;
N2.species = species;
N2.ontologyIdentifier = id;
N2.description = definition;
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

% Define experiment types
switch tableRow.condition{1}
    case 'grid'
        assayType = 'SingleDensityMultiPatch';
    case 'single'
        assayType = 'LargeSinglePatch';
end
switch tableRow.dirName{1}
    case 'foragingConcentration'
        expType = '0';
    case 'foragingMini'
        assayType = 'SmallSinglePatch';
        expType = '1';
    case 'foragingMatching'
        assayType = 'MultiDensityMultiPatch';
        expType = '2';
    case 'foragingMutants'
        expType = '3';
    case 'foragingSensory'
        expType = '4';
end

% Create subjectString
expDate = char(tableRow.expTime,'yyMMdd');
subjectString = join({strain.name{1},[expType,num2str(tableRow.wormNum,'%03.f')],...
    assayType,expDate},'_');
subjectString = [subjectString{1},'@chalasani-lab.salk.edu'];

end % End function createSubjectInformation