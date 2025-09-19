classdef SubjectInformationCreator < ndi.setup.NDIMaker.SubjectInformationCreator
% PULAKAT - Creates NDI subject information for the Pulakat Lab.
%
% This class implements the 'create' method to generate subject identifiers
% and openMINDS objects based on the specific metadata structure used in the
% Pulakat lab's experimental tables for Rattus norvegicus.

methods
    function [subjectIdentifier, strain, species, biologicalSex] = create(obj, tableRow)
        % CREATE - Generates subject data from a Pulakat Lab table row.
        %
        %   [SUBJECTIDENTIFIER, STRAIN, SPECIES, BIOLOGICALSEX] = CREATE(OBJ, TABLEROW)
        %
        %   This method processes a single table row to generate a unique subject
        %   identifier and corresponding openMINDS objects for the subject's
        %   species, strain, and biological sex.
        %
        %   Inputs:
        %       obj (ndi.setup.NDIMaker.SubjectInformationCreator.pulakat) - The instance of this creator class.
        %       tableRow (table) - A single row from a MATLAB table. It must contain the columns
        %                          'Strain', 'Cage', and 'DataLabelRaw'.
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
        requiredCols = {'Strain', 'Cage', 'DataLabelRaw'};
        if ~all(ismember(requiredCols, tableRow.Properties.VariableNames))
            error('ndi:validators:MissingRequiredColumns',...
                'The tableRow is missing one or more required columns for the Pulakat subject creator.');
        end

        % --- Populate openMINDS Objects by calling helper methods ---
        % The creation process is sequential, as some objects depend on others.
        species = obj.createSpeciesObject();
        if ~isobject(species), return; end % Stop if species creation fails

        strain = obj.createStrainObject(tableRow, species);
        if ~isobject(strain), return; end % Stop if strain creation fails

        biologicalSex = obj.createBiologicalSexObject();

        % --- Construct the final subject identifier string ---
        subjectIdentifier = obj.constructSubjectIdentifier(tableRow);
    end
end % methods

methods (Access = private, Static)
    function species = createSpeciesObject()
        % Creates a hardcoded openMINDS species object for Rattus norvegicus.
        species = NaN;
        try
            sp = openminds.controlledterms.Species();
            sp.name = 'Rattus norvegicus';
            sp.preferredOntologyIdentifier = 'NCBITaxon:10116';
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
            st = openminds.core.research.Strain();
            switch tableRow.Strain{1}
                case 'Wistar'
                    st.name = 'WI';
                    st.species = species;
                    st.ontologyIdentifier = 'RRID:RGD_13508588';
                    st.geneticStrainType = 'wildtype';
                    st.description = 'The Wistar rat is an outbred albino rat. This breed was developed at the Wistar Institute in 1906 for use in biological and medical research, and is notably the first rat developed to serve as a model organism.';
                case 'ZDF'
                    st.name = 'ZDF';
                    st.species = species;
                    st.ontologyIdentifier = 'RRID:RGD_70459';
                    st.geneticStrainType = 'wildtype';
                    st.description = '"Zucker" fatty rats of undefined outbred background, inbred with selection for non-insulin-dependent diabetes mellitus by mating diabetic homozygous fatty males to heterozygous sisters (Peterson et al 1990b).';
                otherwise
                    error('ndi:createSubjectInformation:UnknownStrain', ...
                          'Unknown strain type: %s', tableRow.Strain{1});
            end
            strain = st;
        catch ME
            warning('ndi:createSubjectInformation:StrainCreationFailed',...
                'Could not create openMINDS Strain object: %s', ME.message);
        end
    end

    function biologicalSex = createBiologicalSexObject()
        % Creates a hardcoded openMINDS biological sex object for male.
        biologicalSex = NaN;
        try
            bs = openminds.controlledterms.BiologicalSex();
            bs.name = 'male';
            bs.preferredOntologyIdentifier = 'PATO:0000384';
            biologicalSex = bs;
        catch ME
            warning('ndi:createSubjectInformation:BiologicalSexCreationFailed',...
                'Could not create openMINDS BiologicalSex object: %s', ME.message);
        end
    end

    function subjectIdentifier = constructSubjectIdentifier(tableRow)
        % Constructs the subject identifier string from table data.
        subjectIdentifier = NaN;
        try
            % Join the components with underscores
            subjectParts = {tableRow.Cage{1}, tableRow.DataLabelRaw{1}};
            baseString = strjoin(subjectParts, '_');
            
            % Append the lab-specific suffix
            subjectIdentifier = [baseString, '@pulakat-lab.tufts.edu'];
        catch ME
            warning('ndi:createSubjectInformation:IdentifierCreationFailed',...
                'Could not construct the subject identifier string: %s', ME.message);
        end
    end
end % private static methods
end % classdef