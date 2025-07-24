function [ndiDocArray, openMindsObj] = makeSpeciesStrainSex(ndiSession, subjectID, options)
% MAKESPECIESSTRAINSEX - Add species, strain, or sex information for a subject in an ndi.session
%
% [NDIDOCARRAY, OPENMINDSOBJ] = ndi.fun.doc.subject.makeSpeciesStrainSex(ndiSession, subjectID, ...)
%
% Creates openMINDS-standard documents for species, strain, and biological sex,
% linking them to a specified subject document. By default, the documents are only
% created in memory. They can be added to the session's database by setting the
% 'AddToSession' option to true.
%
% This function looks up ontology information for the provided terms and constructs
% the corresponding openMINDS objects, which are then converted to NDI documents.
%
% Inputs:
%   ndiSession (ndi.session) - The NDI session object.
%   subjectID (string)       - The document ID of the 'subject' document to which
%                              this information will be linked.
%
% Optional Name-Value Pair Arguments:
%   'BiologicalSex' (char)   - The biological sex of the subject. Must be one of
%                              'male', 'female', 'hermaphrodite', or 'notDetectable'.
%   'Species' (char)         - The species of the subject, specified as an ontology
%                              identifier (e.g., 'NCBITaxon:10116' for Rattus norvegicus).
%   'Strain' (char)          - The strain of the subject, specified as an ontology
%                              identifier (e.g., 'RRID:RGD_70508' for Sprague Dawley).
%                              Note: 'Species' must also be provided to create a strain document.
%   'AddToSession' (logical) - If true, the created documents are added to the
%                              session's database. Defaults to false.
%
% Outputs:
%   ndiDocArray (cell array) - A cell array of the newly created ndi.document objects.
%   openMindsObj (cell array)- A cell array of the openMINDS objects that were created.
%
% Example:
%   % Assuming 'S' is a valid ndi.session object and 'subject_doc' is a subject document
%   subject_id = subject_doc.id();
%   % Create documents and add them to the session
%   [new_docs, openminds_objs] = ndi.fun.doc.subject.makeSpeciesStrainSex(S, subject_id, ...
%       'Species', 'NCBITaxon:9669', ... % Mustela putorius furo (ferret)
%       'BiologicalSex', 'male', ...
%       'AddToSession', true);
%

    arguments
        % Positional Arguments
        ndiSession (1,1) ndi.session {mustBeNonempty} % Must be a single, non-empty ndi.session object
        subjectID {ndi.validators.mustBeID} % Must be char/string scalar and pass NDI ID validation
        % Optional Name-Value Arguments (options structure)
        options.BiologicalSex (1,:) char ...
             {mustBeMember(options.BiologicalSex, {'', 'male', 'female', 'hermaphrodite', 'notDetectable'})} = ''
        options.Species       (1,:) char = '' % Optional: Species as NCBI Taxonomy identifier
        options.Strain (1,:) char = '' % if you intend to handle strain here too
        options.AddToSession (1,1) logical = false % If true, adds the created documents to the session
    end

    ndiDocArray = {};
    openMindsObj = {};
    speciesObj = []; % To hold the species object for strain dependency

    % 1. Handle Species
    if ~isempty(options.Species)
        try
            [ID, name] = ndi.ontology.lookup(options.Species);
            sp = openminds.controlledterms.Species('name', name, 'preferredOntologyIdentifier', ID);
            speciesObj = sp; % Save for potential use by strain
            openMindsObj{end+1} = sp;
        catch ME
            warning('Could not create openMINDS species object. Error: %s', ME.message);
        end
    end

    % 2. Handle Strain
    if ~isempty(options.Strain)
        if isempty(speciesObj)
            warning('Cannot create a Strain document without a valid Species. Please provide the ''Species'' option.');
        else
            try
                [ID, name] = ndi.ontology.lookup(options.Strain);
                st = openminds.core.research.Strain('name', name, 'species', speciesObj, 'ontologyIdentifier', ID);
                openMindsObj{end+1} = st;
            catch ME
                warning('Could not create openMINDS strain object. Error: %s', ME.message);
            end
        end
    end

    % 3. Handle Biological Sex
    if ~isempty(options.BiologicalSex)
        try
            % PATO is the correct ontology for biological sex
            ontology_map = containers.Map(...
                {'male', 'female', 'hermaphrodite', 'notDetectable'}, ...
                {'PATO:0000384', 'PATO:0000383', 'PATO:0001340', ''});
            
            pato_id = ontology_map(options.BiologicalSex);
            if ~isempty(pato_id)
                [ID, name] = ndi.ontology.lookup(pato_id);
                sex = openminds.controlledterms.BiologicalSex('name', name, 'preferredOntologyIdentifier', ID);
            else % for notDetectable, which has no PATO id
                sex = openminds.controlledterms.BiologicalSex('name', options.BiologicalSex);
            end
            openMindsObj{end+1} = sex;
        catch ME
            warning('Could not create openMINDS biologicalSex object. Error: %s', ME.message);
        end
    end

    % 4. Convert all created openMINDS objects to NDI documents
    if ~isempty(openMindsObj)
        try
            ndiDocArray = ndi.database.fun.openMINDSobj2ndi_document(openMindsObj, ...
                ndiSession.id(), 'subject', subjectID);
            
            % Add the new documents to the session database if requested
            if options.AddToSession
                ndiSession.database_add(ndiDocArray);
            end
        catch ME
            warning('Failed to convert openMINDS objects to NDI documents or add them to the session. Error: %s', ME.message);
            % Clear outputs on failure
            ndiDocArray = {};
            openMindsObj = {};
        end
    end
end

