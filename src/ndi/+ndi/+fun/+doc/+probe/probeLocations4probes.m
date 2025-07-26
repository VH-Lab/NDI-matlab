function probe_location_docs = probeLocations4probes(S, probes, ontology_lookup_strings, options)
    % PROBELOCATIONS4PROBES - Create and add probe_location documents for a set of probes.
    %
    %   DOCS = PROBELOCATIONS4PROBES(S, PROBES, ONTOLOGY_LOOKUP_STRINGS, ...)
    %
    %   Creates NDI documents of type 'probe_location' for each probe specified in the
    %   cell array PROBES. The location for each probe is specified by a corresponding
    %   entry in the ONTOLOGY_LOOKUP_STRINGS cell array.
    %
    %   Inputs:
    %     S - An ndi.session.dir object representing the current session.
    %     PROBES - A cell array of ndi.probe objects.
    %     ONTOLOGY_LOOKUP_STRINGS - A cell array of strings, where each string is a
    %       prefixed term for ontology lookup (e.g., 'UBERON:0000411'). The number
    %       of elements must match the number of probes.
    %
    %   This function also accepts an optional name-value argument:
    %
    %   | Parameter (default) | Description                                  |
    %   |---------------------|----------------------------------------------|
    %   | doAdd (true)        | If true, adds the created documents to the   |
    %   |                     |   session database `S`.                      |
    %
    %   Returns a cell array of the newly created ndi.document objects.
    %
    %   Example:
    %     % Assuming S is an ndi.session.dir object and myprobes is a cell array of probes
    %     locations = {'UBERON:0002436', 'UBERON:0000411'}; % V1, visual cortex
    %     location_docs = probeLocations4probes(S, myprobes, locations);
    %
    
    arguments
        S (1,1) ndi.session.dir
        probes (1,:) cell
        ontology_lookup_strings (1,:) cell
        options.doAdd (1,1) logical = true
    end

    if numel(probes) ~= numel(ontology_lookup_strings)
        error('The number of probes must match the number of ontology_lookup_strings.');
    end

    probe_location_docs = {};

    for i = 1:numel(probes)
        current_probe = probes{i};
        lookup_string = ontology_lookup_strings{i};

        % Step 1: Look up the ontology term
        try
            [id, name, prefix] = ndi.ontology.lookup(lookup_string);
            % Check if the returned ID already includes the prefix, as behavior can vary.
            if startsWith(id, [prefix ':'])
                ontologyName = id;
            else
                ontologyName = [prefix ':' id];
            end
        catch ME
            warning(['Could not look up ontology term ''' lookup_string '''. Skipping probe ' current_probe.probestring() '. Error: ' ME.message]);
            continue; % Skip to the next probe
        end

        % Step 2: Create a new probe_location document
        new_doc = S.newdocument('probe_location');

        % Step 3: Populate the document properties
        new_doc = new_doc.setproperties(...
            'probe_location.ontology_name', ontologyName, ...
            'probe_location.name', name ...
            );

        % Step 4: Set the dependency on the probe
        new_doc = new_doc.set_dependency_value('probe_id', current_probe.id());

        probe_location_docs{end+1} = new_doc;
    end

    % Step 5: Add the documents to the database if requested
    if options.doAdd && ~isempty(probe_location_docs)
        S.database_add(probe_location_docs);
    end

end
