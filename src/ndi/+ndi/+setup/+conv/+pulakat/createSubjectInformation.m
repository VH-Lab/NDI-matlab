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
species.name = 'Rattus norvegicus';
species.preferredOntologyIdentifier = 'NCBITaxon:10116';

% --- Populate Strain openMINDS Object ---
strain = openminds.core.research.Strain;
switch tableRow.Strain{1}
    case 'Wistar'
        strain.name = 'WI';
        strain.species = species;
        strain.ontologyIdentifier = 'RRID:RGD_13508588';
        strain.geneticStrainType = 'wildtype';
        strain.description = 'The Wistar rat is an outbred albino rat. This breed was developed at the Wistar Institute in 1906 for use in biological and medical research, and is notably the first rat developed to serve as a model organism.';
    case 'ZDF'
        strain.name = 'ZDF';
        strain.species = species;
        strain.ontologyIdentifier = 'RRID:RGD_70459';
        strain.geneticStrainType = 'wildtype';
        strain.description = '"Zucker" fatty rats of undefined outbred background, inbred with selection for non-insulin-dependent diabetes mellitus by mating diabetic homozygous fatty males to heterozygous sisters (Peterson et al 1990b).';
end

% --- Populate BiologicalSex openMINDS Object ---
biologicalSex = openminds.controlledterms.BiologicalSex;
biologicalSex.name = 'male';
biologicalSex.preferredOntologyIdentifier = 'PATO:0000384';

% --- Create subject string ---
subjectString = [tableRow.Cage{1},'_',tableRow.DataLabelRaw{1},'@pulakat-lab.tufts.edu'];

end % End function createSubjectInformation