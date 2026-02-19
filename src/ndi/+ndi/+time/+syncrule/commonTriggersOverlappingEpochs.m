classdef commonTriggersOverlappingEpochs < ndi.time.syncrule

    properties (SetAccess=protected,GetAccess=public)
    end % properties
    properties (SetAccess=protected,GetAccess=protected)
    end % properties
    methods
        function ndi_syncrule_ctoe_obj = commonTriggersOverlappingEpochs(varargin)
            % COMMONTRIGGERSOVERLAPPINGEPOCHS - create a new ndi.time.syncrule.commonTriggersOverlappingEpochs object
            %
            % NDI_SYNCRULE_CTOE_OBJ = ndi.time.syncrule.commonTriggersOverlappingEpochs()
            %      or
            % NDI_SYNCRULE_CTOE_OBJ = ndi.time.syncrule.commonTriggersOverlappingEpochs(PARAMETERS)
            %
            % Creates a new ndi.time.syncrule.commonTriggersOverlappingEpochs object with the given PARAMETERS.
            % If no inputs are provided, then the default PARAMETERS (see below) is used.
            %
            % PARAMETERS should be a structure with the following entries:
            % Field (default)              | Description
            % -------------------------------------------------------------------
            % daqsystem1_name ('')         | Name of one of the daq systems
            % daqsystem2_name ('')         | Name of the other daq system
            % daqsystem_ch1 ('')           | The channel to read on daq system 1 (e.g., 'dep1')
            % daqsystem_ch2 ('')           | The channel to read on daq system 2 (e.g., 'mk1')
            % epochclocktype ('dev_local_time') | The epoch clock type to consider
            % minEmbeddedFileOverlap (1)   | The minimum number of embedded file matches (parent or grandparent directories) required
            % errorOnFailure (true)        | If the trigger synchronization fails, cause an error.
            %
            if nargin==0
                parameters = struct('daqsystem1_name','', 'daqsystem2_name','', ...
                    'daqsystem_ch1','', 'daqsystem_ch2','', ...
                    'epochclocktype','dev_local_time', ...
                    'minEmbeddedFileOverlap', 1, 'errorOnFailure', true);
                varargin = {parameters};
            end
            ndi_syncrule_ctoe_obj = ndi_syncrule_ctoe_obj@ndi.time.syncrule(varargin{:});
        end

        function [b,msg] = isvalidparameters(ndi_syncrule_ctoe_obj, parameters)
            % ISVALIDPARAMETERS - determine if a parameter structure is valid for a given ndi.time.syncrule.commonTriggersOverlappingEpochs
            %
            % [B,MSG] = ISVALIDPARAMETERS(NDI_SYNCRULE_CTOE_OBJ, PARAMETERS)
            %
            % Returns 1 if PARAMETERS is a valid parameter structure. Returns 0 otherwise.
            %
            % See also: ndi.time.syncrule/SETPARAMETERS

            [b,msg] = vlt.data.hasAllFields(parameters,{'daqsystem1_name','daqsystem2_name',...
                'daqsystem_ch1','daqsystem_ch2','epochclocktype','minEmbeddedFileOverlap','errorOnFailure'});
            if b
                if ~ischar(parameters.daqsystem1_name) || ~ischar(parameters.daqsystem2_name) || ...
                        ~ischar(parameters.daqsystem_ch1) || ~ischar(parameters.daqsystem_ch2) || ...
                        ~ischar(parameters.epochclocktype)
                    b = 0;
                    msg = 'daqsystem names, channels, and epochclocktype must be strings.';
                end
                if ~isnumeric(parameters.minEmbeddedFileOverlap)
                    b = 0;
                    msg = 'minEmbeddedFileOverlap must be a number.';
                end
                if ~islogical(parameters.errorOnFailure) && ~isnumeric(parameters.errorOnFailure)
                    b = 0;
                    msg = 'errorOnFailure must be logical or numeric (0/1).';
                end
            end
            return;
        end % isvalidparameters

        function ees = eligibleepochsets(ndi_syncrule_ctoe_obj)
            % ELIGIBLEEPOCHSETS - return a cell array of eligible ndi.epoch.epochset class names
            %
            % EES = ELIGIBLEEPOCHSETS(NDI_SYNCRULE_CTOE_OBJ)
            %
            % Returns {'ndi.daq.system'}.
            ees = {'ndi.daq.system'};
        end % eligibleepochsets

        function ies = ineligibleepochsets(ndi_syncrule_ctoe_obj)
            % INELIGIBLEEPOCHSETS - return a cell array of ineligible ndi.epoch.epochset class names
            %
            % IES = INELIGIBLEEPOCHSETS(NDI_SYNCRULE_CTOE_OBJ)
            %
            % Returns a cell array of ndi.epoch.epochset subclasses that the rule cannot process.
            ies = cat(2,ndi_syncrule_ctoe_obj.ineligibleepochsets@ndi.time.syncrule(),...
                {'ndi.epoch.epochset','ndi.epoch.epochset.param','ndi.file.navigator'});
        end % ineligibleepochsets

        function [cost,mapping] = apply(ndi_syncrule_ctoe_obj, epochnode_a, epochnode_b, daqsystem_a)
            % APPLY - apply the sync rule to obtain a cost and mapping
            %
            % [COST, MAPPING] = APPLY(NDI_SYNCRULE_CTOE_OBJ, EPOCHNODE_A, EPOCHNODE_B, DAQSYSTEM_A)
            %
            % Given the sync rule and two epochnodes, attempts to identify whether synchronization can be made.
            % DAQSYSTEM_A is the ndi.daq.system corresponding to EPOCHNODE_A.
            %
            cost = [];
            mapping = [];

            p = ndi_syncrule_ctoe_obj.parameters;

            % 1. Verify epochnodes match parameters
            % Identify which is system 1 and which is system 2 based on objectname

            node_a_is_1 = strcmp(epochnode_a.objectname, p.daqsystem1_name);
            node_a_is_2 = strcmp(epochnode_a.objectname, p.daqsystem2_name);
            node_b_is_1 = strcmp(epochnode_b.objectname, p.daqsystem1_name);
            node_b_is_2 = strcmp(epochnode_b.objectname, p.daqsystem2_name);

            if ~((node_a_is_1 && node_b_is_2) || (node_a_is_2 && node_b_is_1))
                return; % Names do not match the pair we are looking for
            end

            % Check epoch clock type
            if ~strcmp(epochnode_a.epoch_clock.type, p.epochclocktype) || ...
               ~strcmp(epochnode_b.epoch_clock.type, p.epochclocktype)
                return; % Clock types do not match
            end

            % Assign roles
            if node_a_is_1
                % A is 1, B is 2
                daqsystem1 = daqsystem_a;
                % We need daqsystem2. Get session from daqsystem1.
                session = daqsystem1.session;
                daqsystem2 = session.daqsystem_load('name', p.daqsystem2_name);
                epochnode1 = epochnode_a;
                epochnode2 = epochnode_b;
            else
                % A is 2, B is 1
                daqsystem2 = daqsystem_a;
                session = daqsystem2.session;
                daqsystem1 = session.daqsystem_load('name', p.daqsystem1_name);
                epochnode1 = epochnode_b;
                epochnode2 = epochnode_a;
            end

            if isempty(daqsystem1) || isempty(daqsystem2)
                if p.errorOnFailure
                    error('Could not load both DAQ systems.');
                else
                    return;
                end
            end

            if iscell(daqsystem1), daqsystem1 = daqsystem1{1}; end
            if iscell(daqsystem2), daqsystem2 = daqsystem2{1}; end

            % 2. Look for existing syncrule_mapping in database
            q_existing = ndi.query('','isa','syncrule_mapping') & ...
                ndi.query('syncrule_mapping.epochnode_a.epoch_id', 'exact_string', epochnode_a.epoch_id) & ...
                ndi.query('syncrule_mapping.epochnode_b.epoch_id', 'exact_string', epochnode_b.epoch_id) & ...
                ndi.query('syncrule_mapping.epochnode_a.objectname', 'exact_string', epochnode_a.objectname) & ...
                ndi.query('syncrule_mapping.epochnode_b.objectname', 'exact_string', epochnode_b.objectname);

            existing_docs = session.database_search(q_existing);
            if ~isempty(existing_docs)
                % Found existing mapping
                doc = existing_docs{1};
                cost = doc.document_properties.syncrule_mapping.cost;
                mapping = ndi.time.timemapping(doc.document_properties.syncrule_mapping.mapping);
                return;
            end

            % 3. Find relationship / overlaps
            % Start with seed epochs

            % Check initial overlap
            files_a = epochnode_a.underlying_epochs.underlying;
            files_b = epochnode_b.underlying_epochs.underlying;

            count1 = count_embedded_matches(files_a, files_b);
            count2 = count_embedded_matches(files_b, files_a);

            if max(count1, count2) < p.minEmbeddedFileOverlap
                return;
            end

            % Expand search
            epochs_a_all = daqsystem_a.epochtable();
            if node_a_is_1
                 epochs_b_all = daqsystem2.epochtable();
            else
                 epochs_b_all = daqsystem1.epochtable();
            end

            % Identify epoch IDs
            id_a_seed = epochnode_a.epoch_id;
            id_b_seed = epochnode_b.epoch_id;

            % Find indices in epoch table
            idx_a_seed = find(strcmp({epochs_a_all.epoch_id}, id_a_seed));
            idx_b_seed = find(strcmp({epochs_b_all.epoch_id}, id_b_seed));

            if isempty(idx_a_seed) || isempty(idx_b_seed)
                 return; % Should not happen
            end

            % Sets of indices of epochs in the expanded group
            group_a_indices = [idx_a_seed];
            group_b_indices = [idx_b_seed];

            added = true;
            while added
                added = false;

                % Check A against all B in group
                for i = 1:numel(epochs_a_all)
                    if ismember(i, group_a_indices), continue; end
                    % Check overlap with ANY in group B
                    for j = 1:numel(group_b_indices)
                        b_idx = group_b_indices(j);
                        f_a = epochs_a_all(i).underlying_epochs.underlying;
                        f_b = epochs_b_all(b_idx).underlying_epochs.underlying;
                        c1 = count_embedded_matches(f_a, f_b);
                        c2 = count_embedded_matches(f_b, f_a);

                        if max(c1, c2) >= p.minEmbeddedFileOverlap
                            group_a_indices(end+1) = i;
                            added = true;
                            break;
                        end
                    end
                end

                % Check B against all A in group
                for i = 1:numel(epochs_b_all)
                    if ismember(i, group_b_indices), continue; end
                    for j = 1:numel(group_a_indices)
                        a_idx = group_a_indices(j);
                        f_b = epochs_b_all(i).underlying_epochs.underlying;
                        f_a = epochs_a_all(a_idx).underlying_epochs.underlying;
                        c1 = count_embedded_matches(f_b, f_a);
                        c2 = count_embedded_matches(f_a, f_b);

                        if max(c1, c2) >= p.minEmbeddedFileOverlap
                            group_b_indices(end+1) = i;
                            added = true;
                            break;
                        end
                    end
                end
            end

            try
                % 4. Read Triggers
                T1_total = [];
                T2_total = [];

                [type1, ch1] = parse_channel(p.daqsystem_ch1);
                [type2, ch2] = parse_channel(p.daqsystem_ch2);

                % Read from DAQ 1 (which corresponds to node_a if node_a_is_1, else node_b)
                % Actually we have daqsystem1 object and group indices for it.
                % But wait, group_a_indices correspond to daqsystem_a.
                % If daqsystem_a is daqsystem1, then group_a_indices -> daqsystem1.
                % If daqsystem_a is daqsystem2, then group_a_indices -> daqsystem2.

                if node_a_is_1
                    indices_1 = group_a_indices;
                    indices_2 = group_b_indices;
                    epochs_1 = epochs_a_all;
                    epochs_2 = epochs_b_all;
                else
                    indices_1 = group_b_indices;
                    indices_2 = group_a_indices;
                    epochs_1 = epochs_b_all;
                    epochs_2 = epochs_a_all;
                end

                % Sort indices by time (t0) to ensure correct concatenation order
                t0_1 = zeros(1, numel(indices_1));
                for k = 1:numel(indices_1)
                    t0t1 = epochs_1(indices_1(k)).t0_t1;
                    if iscell(t0t1), t0t1 = t0t1{1}; end
                    t0_1(k) = t0t1(1);
                end
                [~, sort_idx_1] = sort(t0_1);
                indices_1 = indices_1(sort_idx_1);

                t0_2 = zeros(1, numel(indices_2));
                for k = 1:numel(indices_2)
                    t0t1 = epochs_2(indices_2(k)).t0_t1;
                    if iscell(t0t1), t0t1 = t0t1{1}; end
                    t0_2(k) = t0t1(1);
                end
                [~, sort_idx_2] = sort(t0_2);
                indices_2 = indices_2(sort_idx_2);

                % Read T1
                for k = 1:numel(indices_1)
                    eid = epochs_1(indices_1(k)).epoch_id;
                    [ts, ~] = daqsystem1.readevents(type1, ch1, eid, -Inf, Inf);
                    if iscell(ts), ts = ts{1}; end
                    T1_total = [T1_total; ts(:)];
                end

                % Read T2
                for k = 1:numel(indices_2)
                    eid = epochs_2(indices_2(k)).epoch_id;
                    [ts, ~] = daqsystem2.readevents(type2, ch2, eid, -Inf, Inf);
                    if iscell(ts), ts = ts{1}; end
                    T2_total = [T2_total; ts(:)];
                end

                % 5. Compute Mapping
                map_coeffs = vlt.time.syncTriggers(T1_total, T2_total);
                % map_coeffs is [shift scale] -> T2 = shift + scale * T1
                % ndi.time.timemapping expects [m b] where y = m*x + b.
                % Wait, let's check vlt.time.syncTriggers description again.
                % "T2 is approximately equal to shift + scale * T1"
                % So T2 = scale * T1 + shift.
                % ndi.time.timemapping([m b]) means y = m*x + b.
                % So m = scale, b = shift.
                % But wait, vlt.time.syncTriggers returns [shift scale].
                % So mapping params should be [scale shift].

                cost = 1; % As requested
                mapping = ndi.time.timemapping([map_coeffs(2) map_coeffs(1)]);

                % If we were asked to map A to B:
                % If A is 1 and B is 2: T2 = scale*T1 + shift. Map T1 -> T2. Correct.
                % If A is 2 and B is 1: We computed T2 = scale*T1 + shift.
                % But we want map A -> B. i.e. T2 -> T1.
                % T1 = (T2 - shift)/scale = (1/scale)*T2 - shift/scale.

                if ~node_a_is_1
                    % We computed 1->2 (T1->T2). But we want A->B (2->1).
                    % Current mapping is 1->2: y = m*x + c.
                    % We want x = (y-c)/m = (1/m)*y - c/m.
                    m = map_coeffs(2);
                    c = map_coeffs(1);
                    mapping = ndi.time.timemapping([1/m -c/m]);
                end

            catch ME
                if p.errorOnFailure
                    rethrow(ME);
                else
                    cost = [];
                    mapping = [];
                end
            end

        end % apply

    end % methods
end % classdef

% Helper to parse channel
function [ch_type, ch_num] = parse_channel(ch_str)
    % e.g. 'dep1' -> 'dep', 1
    first_digit = find(isstrprop(ch_str, 'digit'), 1);
    if isempty(first_digit)
        error(['Invalid channel string: ' ch_str]);
    end
    ch_type = ch_str(1:first_digit-1);
    ch_num = str2double(ch_str(first_digit:end));
end

function parents = get_parents(files)
    parents = {};
    if ischar(files), files = {files}; end
    for i=1:numel(files)
        parents{end+1} = fileparts(files{i});
    end
    parents = unique(parents);
end

function grandparents = get_grandparents(files)
    grandparents = {};
    if ischar(files), files = {files}; end
    for i=1:numel(files)
        p = fileparts(files{i});
        grandparents{end+1} = fileparts(p);
    end
    grandparents = unique(grandparents);
end

function count = count_embedded_matches(files_deep, files_shallow)
    % Counts how many files in files_deep have a grandparent that matches a parent of a file in files_shallow
    gps = get_grandparents(files_deep);
    ps = get_parents(files_shallow);
    % Actually, requirements say: "grandparent of EACH file in epochnode_1 and compare to the parent of EACH file in epochnode_2"
    % "asking whether there are at least minEmbeddedFileOverlap matches"
    % This implies counting file-level matches?
    % "grandparent of EACH file... compare... matches"
    % If I have 10 files in A, and all 10 have grandparent "X".
    % If B has 1 file with parent "X".
    % Then all 10 files in A match. Count = 10.

    count = 0;
    if ischar(files_deep), files_deep = {files_deep}; end

    % We need the SET of parents from shallow to check against
    ps_set = ps; % already unique from get_parents, but wait
    % get_parents returns unique parents.

    for i=1:numel(files_deep)
        p = fileparts(files_deep{i});
        gp = fileparts(p);
        if ismember(gp, ps_set)
            count = count + 1;
        end
    end
end
