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
N2.description = 'C. elegans var Bristol. Generation time is about 3 days. Brood size is about 350. Also CGC reference 257. Isolated from mushroom compost near Bristol, England by L.N. Staniland. Cultured by W.L. Nicholas, identified to genus by Gunther Osche and species by Victor Nigon; subsequently cultured by C.E. Dougherty. Given to Sydney Brenner ca. 1966. Subcultured by Don Riddle in 1973. Caenorhabditis elegans wild isolate. DR subclone of CB original (Tc1 pattern I).';
N2.geneticStrainType = 'wild type';

switch tableRow.strain{1}
    case 'WBStrain:00000001'
        strain = N2;
    case 'WBStrain:00030796'
        strain = openminds.core.research.Strain;
        strain.name = 'PR811';
        strain.species = species;
        strain.ontologyIdentifier = 'WBStrain:00030796';
        strain.description = 'osm-6(p811) V. Fails to avoid high osmotic strength solutions of NaCl and fructose. Fails to stain amphids with FITC.';
        strain.laboratoryCode = 'NW';
        strain.geneticStrainType = 'mutant';
        strain.backgroundStrain = N2;
        strain.phenotype = 'Fails to avoid high osmotic strength solutions of NaCl and fructose. Fails to stain amphids with FITC.';
        strain.synonym = 'osm-6(p811) V';
    case 'WBStrain:00035037'
        strain = openminds.core.research.Strain;
        strain.name = 'TU253';
        strain.species = species;
        strain.ontologyIdentifier = 'WBStrain:00035037';
        strain.description = 'mec-4(u253) X. Mechanosensory abnormal. Recessive.';
        strain.laboratoryCode = 'UA';
        strain.geneticStrainType = 'mutant';
        strain.backgroundStrain = N2;
        strain.phenotype = 'Mechanosensory abnormal.';
        strain.synonym = 'mec-4(u253) X';
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
subjectString = join({strain.name{1},[expType,num2str(tableRow.wormNum,'%03.f')],...
    assayType,tableRow.expDate{1}},'_');
subjectString = [subjectString{1},'@chalasani-lab.salk.edu'];

end % End function createSubjectInformation