classdef SubjectInformationCreator < ndi.setup.NDIMaker.SubjectInformationCreator
% HALEY - Creates NDI subject information for the Hunsberger Lab.
%
% This class implements the 'create' method to generate subject identifiers
% and openMINDS objects based on the specific metadata structure used in the
% Hunsberger lab's experimental tables.

methods
    function [subjectIdentifier, strain, species, biologicalSex] = create(obj, tableRow)
        % CREATE - Generates subject data from a Hunsberger Lab table row.
        %
        %   [SUBJECTIDENTIFIER, STRAIN, SPECIES, BIOLOGICALSEX] = CREATE(OBJ, TABLEROW)
        %
        %   This method processes a single table row to generate a unique subject
        %   identifier and corresponding openMINDS objects for the subject's
        %   species, strain, and biological sex.
        %
        %   Inputs:
        %       obj (ndi.setup.NDIMaker.SubjectInformationCreator) - The instance of this creator class.
        %       tableRow (table) - A single row from a MATLAB table.
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

        % --- Populate openMINDS Objects by calling helper methods ---
        % The creation process is sequential, as some objects depend on others.
        species = obj.createSpeciesObject();
        if ~isobject(species), return; end % Stop if species creation fails

        strain = obj.createStrainObject(tableRow, species);
        if ~isobject(strain), return; end % Stop if strain creation fails

        biologicalSex = obj.createBiologicalSexObject(tableRow);

        % --- Construct the final subject identifier string ---
        subjectIdentifier = obj.constructSubjectIdentifier(tableRow, strain);
    end
end % methods

methods (Access = private, Static)

    function species = createSpeciesObject()
        % Creates an openMINDS species object for M. musculus.
        species = NaN;
        try
            sp = openminds.controlledterms.Species();
            sp.name = 'Mus musculus';
            sp.preferredOntologyIdentifier = 'NCBITaxon:10090';
            sp.synonym = 'house mouse';
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
            % Define the 129S/SvEv strain, which may be the background strain
            SvEv = openminds.core.research.Strain();
            SvEv.name = '129S/SvEv';
            SvEv.species = species;
            SvEv.ontologyIdentifier = 'NCIT:C37334';
            SvEv.geneticStrainType = 'wildtype';

            strainID = tableRow.StrainType{1};
            if strcmp(strainID, '129S6/SvEv')
                strain = SvEv;
            elseif strcmp(strainID, 'ArcCreERT2 x eYFP')
                ArcCreERT2 = openminds.core.research.Strain();
                [id, name, ~, definition] = ndi.ontology.lookup('EMPTY:00000284');
                ArcCreERT2.name = name;
                ArcCreERT2.species = species;
                ArcCreERT2.ontologyIdentifier = id;
                ArcCreERT2.description = definition;
                ArcCreERT2.geneticStrainType = 'transgenic';
                ArcCreERT2.backgroundStrain = SvEv;

                eYFP = openminds.core.research.Strain();
                [id, name, ~, definition] = ndi.ontology.lookup('EMPTY:00000287');
                eYFP.name = name;
                eYFP.species = species;
                eYFP.ontologyIdentifier = id;
                eYFP.description = definition;
                eYFP.geneticStrainType = 'transgenic';
                eYFP.backgroundStrain = SvEv;

                strain = openminds.core.research.Strain();
                [id, name, ~, definition] = ndi.ontology.lookup('EMPTY:00000288');
                strain.name = name;
                strain.species = species;
                strain.ontologyIdentifier = id;
                strain.description = definition;
                strain.geneticStrainType = 'transgenic';
                strain.backgroundStrain = [ArcCreERT2,eYFP];
            end
        catch ME
            warning('ndi:createSubjectInformation:StrainCreationFailed',...
                'Could not create openMINDS Strain object: %s', ME.message);
        end
    end

    function biologicalSex = createBiologicalSexObject(tableRow)
        % Creates an openMINDS biological sex object.
        biologicalSex = NaN;
        try
            sex = tableRow.Sex{1};
            if strcmp(sex, 'F')
                biologicalSex = openminds.controlledterms.BiologicalSex(...
                    'name','female','preferredOntologyIdentifier','PATO:0000383');
            elseif strcmp(sex, 'M')
                biologicalSex = openminds.controlledterms.BiologicalSex(...
                    'name','male','preferredOntologyIdentifier','PATO:0000384');
            end
        catch ME
            warning('ndi:createSubjectInformation:BiologicalSexCreationFailed',...
                'Could not create openMINDS BiologicalSex object: %s', ME.message);
        end
    end

    function subjectIdentifier = constructSubjectIdentifier(tableRow, strain)
        % Constructs the subject identifier string from table data.
        subjectIdentifier = NaN;
        try
            % Format the strain name
            strainName = replace(tableRow.StrainType{1},' ','');

            % Format ID
            if ~isnan(tableRow.ID)
                id = num2str(tableRow.ID);
            else
                id = '';
            end

            % Format the experiment date to 'yyMMdd'
            expDate = char(datetime(tableRow.DOB), 'yyMMdd');

            % Join the components with underscores
            subjectParts = {'mouse',strainName, tableRow.Condition{1},...
                 tableRow.Sex{1}, id, tableRow.BoxNumber{1}, expDate};
            baseString = strjoin(subjectParts, '_');
            baseString = replace(baseString,'_ _','_');
            baseString = replace(baseString,'_NaT','');

            % Append the lab-specific suffix
            subjectIdentifier = [baseString, '@hunsberger-lab.rosalindfranklin.edu'];
        catch ME
            warning('ndi:createSubjectInformation:IdentifierCreationFailed',...
                'Could not construct the subject identifier string: %s', ME.message);
        end
    end

end % private static methods
end % classdef