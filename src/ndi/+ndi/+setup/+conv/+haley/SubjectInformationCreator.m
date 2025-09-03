classdef SubjectInformationCreator < ndi.setup.NDIMaker.SubjectInformationCreator
% HALEY - Creates NDI subject information for the Chalasani Lab.
%
% This class implements the 'create' method to generate subject identifiers
% and openMINDS objects based on the specific metadata structure used in the
% Chalasani lab's experimental tables for C. elegans.

methods
    function [subjectIdentifier, strain, species, biologicalSex] = create(obj, tableRow)
        % CREATE - Generates subject data from a Haley Lab table row.
        %
        %   [SUBJECTIDENTIFIER, STRAIN, SPECIES, BIOLOGICALSEX] = CREATE(OBJ, TABLEROW)
        %
        %   This method processes a single table row to generate a unique subject
        %   identifier and corresponding openMINDS objects for the subject's
        %   species, strain, and biological sex.
        %
        %   Inputs:
        %       obj (ndi.setup.NDIMaker.SubjectInformationCreator.haley) - The instance of this creator class.
        %       tableRow (table) - A single row from a MATLAB table. It must contain the columns
        %                          'strain', 'expTime', 'wormID', and 'assayType'.
        %
        %   Outputs:
        %       subjectIdentifier (char) - The unique local identifier string for the subject.
        %                                  Returns NaN on failure.
        %       strain (openminds.core.research.Strain) - The corresponding openMINDS strain object.
        %                                                   Returns NaN on failure.
        %       species (openminds.controlledterms.Species) - The openMINDS species object.
        %                                                       Returns NaN on failure.
        %       biologicalSex (openminds.controlledterms.BiologicalSex) - The openMINDS biological sex object.
        %                                                                   Returns NaN on failure.
        %
        %   See also: ndi.setup.NDIMaker.SubjectInformationCreator
        %

        % --- Validate required columns ---
        requiredCols = {'strain', 'expTime', 'wormID', 'assayType'};
        if ~all(ismember(requiredCols, tableRow.Properties.VariableNames))
            error('ndi:validators:MissingRequiredColumns',...
                'The tableRow is missing one or more required columns for the Haley subject creator.');
        end

        % --- Populate openMINDS Objects by calling helper methods ---
        % The creation process is sequential, as some objects depend on others.
        species = obj.createSpeciesObject();
        if ~isobject(species), return; end % Stop if species creation fails

        strain = obj.createStrainObject(tableRow, species);
        if ~isobject(strain), return; end % Stop if strain creation fails

        biologicalSex = obj.createBiologicalSexObject();

        % --- Construct the final subject identifier string ---
        subjectIdentifier = obj.constructSubjectIdentifier(tableRow, strain);
    end
end % methods

methods (Access = private, Static)

    function species = createSpeciesObject()
        % Creates a hardcoded openMINDS species object for C. elegans.
        species = NaN;
        try
            sp = openminds.controlledterms.Species();
            sp.name = 'Caenorhabditis elegans';
            sp.preferredOntologyIdentifier = 'NCBITaxon:6239';
            sp.definition = 'Caenorhabditis elegans is a species of nematode in the family Rhabditidae that is widely used as an experimental model organism.';
            sp.synonym = 'C. elegans';
            species = sp;
        catch ME
            warning('ndi:createSubjectInformation:SpeciesCreationFailed',...
                'Could not create openMINDS Species object: %s', ME.message);
        end
    end

    function strain = createStrainObject(tableRow, species)
        % Creates an openMINDS strain object based on the table row data.
        strain = NaN;
        try
            % Define the wild type N2 strain, which may be the background strain
            N2 = openminds.core.research.Strain();
            N2.name = 'N2';
            N2.species = species;
            N2.ontologyIdentifier = 'WBStrain:00000001';
            N2.description = 'Genotype: Caenorhabditis elegans wild isolate.';
            N2.geneticStrainType = 'wild type';

            strainID = tableRow.strain{1};
            if strcmp(strainID, 'WBStrain:00000001')
                % If the strain is N2, use the object we just created
                strain = N2;
            else
                % Otherwise, create a new transgenic strain object
                st_trans = openminds.core.research.Strain();
                [id, name, ~, definition] = ndi.ontology.lookup(strainID);
                st_trans.name = name;
                st_trans.species = species;
                st_trans.ontologyIdentifier = id;
                st_trans.description = definition;
                st_trans.geneticStrainType = 'transgenic';
                st_trans.backgroundStrain = N2; % Set N2 as the background
                strain = st_trans;
            end
        catch ME
            warning('ndi:createSubjectInformation:StrainCreationFailed',...
                'Could not create openMINDS Strain object: %s', ME.message);
        end
    end

    function biologicalSex = createBiologicalSexObject()
        % Creates a hardcoded openMINDS biological sex object for hermaphrodite.
        biologicalSex = NaN;
        try
            bs = openminds.controlledterms.BiologicalSex();
            bs.name = 'hermaphrodite';
            bs.preferredOntologyIdentifier = 'PATO:0001340';
            biologicalSex = bs;
        catch ME
            warning('ndi:createSubjectInformation:BiologicalSexCreationFailed',...
                'Could not create openMINDS BiologicalSex object: %s', ME.message);
        end
    end

    function subjectIdentifier = constructSubjectIdentifier(tableRow, strain)
        % Constructs the subject identifier string from table data.
        subjectIdentifier = NaN;
        try
            % Format the experiment date to 'yyMMdd'
            expDate = char(datetime(tableRow.expTime{1}), 'yyMMdd');

            % Join the components with underscores
            subjectParts = {strain.name{1}, tableRow.wormID{1}, tableRow.assayType{1}, expDate};
            baseString = strjoin(subjectParts, '_');

            % Append the lab-specific suffix
            subjectIdentifier = [baseString, '@chalasani-lab.salk.edu'];
        catch ME
            warning('ndi:createSubjectInformation:IdentifierCreationFailed',...
                'Could not construct the subject identifier string: %s', ME.message);
        end
    end

end % private static methods
end % classdef