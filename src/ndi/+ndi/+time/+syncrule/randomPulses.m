classdef randomPulses < ndi.time.syncrule
    % RANDOMPULSES - syncrule based on random pulse sequences on a shared channel
    %
    % This sync rule synchronizes two DAQ systems that recorded a shared random pulse sequence.
    % It uses ndi.time.fun.syncRandomTriggers to find the mapping between the two sequences.
    %

    properties (SetAccess=protected,GetAccess=public)
    end % properties
    properties (SetAccess=protected,GetAccess=protected)
    end % properties
    methods
        function ndi_syncrule_rp_obj = randomPulses(varargin)
            % RANDOMPULSES - create a new ndi.time.syncrule.randomPulses object
            %
            % NDI_SYNCRULE_RP_OBJ = ndi.time.syncrule.randomPulses()
            %      or
            % NDI_SYNCRULE_RP_OBJ = ndi.time.syncrule.randomPulses(PARAMETERS)
            %
            % Creates a new ndi.time.syncrule.randomPulses object with the given PARAMETERS.
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
            % errorOnFailure (true)        | If the trigger synchronization fails, cause an error.
            %
            if nargin==0
                parameters = struct('daqsystem1_name','', 'daqsystem2_name','', ...
                    'daqsystem_ch1','', 'daqsystem_ch2','', ...
                    'epochclocktype','dev_local_time', ...
                    'errorOnFailure', true);
                varargin = {parameters};
            end
            ndi_syncrule_rp_obj = ndi_syncrule_rp_obj@ndi.time.syncrule(varargin{:});
        end

        function [b,msg] = isvalidparameters(ndi_syncrule_rp_obj, parameters)
            % ISVALIDPARAMETERS - determine if a parameter structure is valid for a given ndi.time.syncrule.randomPulses
            %
            % [B,MSG] = ISVALIDPARAMETERS(NDI_SYNCRULE_RP_OBJ, PARAMETERS)
            %
            % Returns 1 if PARAMETERS is a valid parameter structure. Returns 0 otherwise.
            %
            % See also: ndi.time.syncrule/SETPARAMETERS

            [b,msg] = vlt.data.hasAllFields(parameters,{'daqsystem1_name','daqsystem2_name',...
                'daqsystem_ch1','daqsystem_ch2','epochclocktype','errorOnFailure'});
            if b
                if ~ischar(parameters.daqsystem1_name) || ~ischar(parameters.daqsystem2_name) || ...
                        ~ischar(parameters.daqsystem_ch1) || ~ischar(parameters.daqsystem_ch2) || ...
                        ~ischar(parameters.epochclocktype)
                    b = 0;
                    msg = 'daqsystem names, channels, and epochclocktype must be strings.';
                end
                if ~islogical(parameters.errorOnFailure) && ~isnumeric(parameters.errorOnFailure)
                    b = 0;
                    msg = 'errorOnFailure must be logical or numeric (0/1).';
                end
            end
            return;
        end % isvalidparameters

        function ees = eligibleepochsets(ndi_syncrule_rp_obj)
            % ELIGIBLEEPOCHSETS - return a cell array of eligible ndi.epoch.epochset class names
            %
            % EES = ELIGIBLEEPOCHSETS(NDI_SYNCRULE_RP_OBJ)
            %
            % Returns {'ndi.daq.system.mfdaq'}.
            ees = {'ndi.daq.system.mfdaq'};
        end % eligibleepochsets

        function ies = ineligibleepochsets(ndi_syncrule_rp_obj)
            % INELIGIBLEEPOCHSETS - return a cell array of ineligible ndi.epoch.epochset class names
            %
            % IES = INELIGIBLEEPOCHSETS(NDI_SYNCRULE_RP_OBJ)
            %
            % Returns a cell array of ndi.epoch.epochset subclasses that the rule cannot process.
            ies = cat(2,ndi_syncrule_rp_obj.ineligibleepochsets@ndi.time.syncrule(),...
                {'ndi.epoch.epochset','ndi.epoch.epochset.param','ndi.file.navigator'});
        end % ineligibleepochsets

        function [cost,mapping] = apply(ndi_syncrule_rp_obj, epochnode_a, epochnode_b, daqsystem1)
            % APPLY - apply the sync rule to obtain a cost and mapping
            %
            % [COST, MAPPING] = APPLY(NDI_SYNCRULE_RP_OBJ, EPOCHNODE_A, EPOCHNODE_B, DAQSYSTEM1)
            %
            % Given the sync rule and two epochnodes, attempts to identify whether synchronization can be made.
            % DAQSYSTEM1 is the ndi.daq.system corresponding to EPOCHNODE_A.
            %
            cost = [];
            mapping = [];

            p = ndi_syncrule_rp_obj.parameters;

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
                daqsystem_a = daqsystem1;
                % We need daqsystem2. Get session from daqsystem1.
                session = daqsystem_a.session;
                daqsystem_b = session.daqsystem_load('name', p.daqsystem2_name);
                epochnode_1 = epochnode_a;
                epochnode_2 = epochnode_b;
            else
                % A is 2, B is 1
                daqsystem_b = daqsystem1;
                session = daqsystem_b.session;
                daqsystem_a = session.daqsystem_load('name', p.daqsystem1_name);
                epochnode_1 = epochnode_b;
                epochnode_2 = epochnode_a;
            end

            if isempty(daqsystem_a) || isempty(daqsystem_b)
                if p.errorOnFailure
                    error('Could not load both DAQ systems.');
                else
                    return;
                end
            end

            if iscell(daqsystem_a), daqsystem_a = daqsystem_a{1}; end
            if iscell(daqsystem_b), daqsystem_b = daqsystem_b{1}; end

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

            try
                % 3. Read Triggers

                [type1, ch1] = parse_channel(p.daqsystem_ch1);
                [type2, ch2] = parse_channel(p.daqsystem_ch2);

                % Read T1
                eid1 = epochnode_1.epoch_id;
                [ts1, ~] = daqsystem_a.readevents({type1}, ch1, eid1, -Inf, Inf);
                if iscell(ts1), ts1 = ts1{1}; end
                T1 = ts1(:);

                % Read T2
                eid2 = epochnode_2.epoch_id;
                [ts2, ~] = daqsystem_b.readevents({type2}, ch2, eid2, -Inf, Inf);
                if iscell(ts2), ts2 = ts2{1}; end
                T2 = ts2(:);

                % 4. Compute Mapping
                % t1 = shift + scale * t2
                [shift, scale] = ndi.time.fun.syncRandomTriggers(sort(T1), sort(T2));

                if isnan(shift) || isnan(scale)
                    if p.errorOnFailure
                        error('Could not find random pulse match.');
                    else
                        return;
                    end
                end

                % t1 = scale * t2 + shift
                % mapping expects [scale shift] for y = scale*x + shift. (Mapping maps x to y)
                % so mapping from 2 to 1 (T2 -> T1) is [scale shift]
                % If we want mapping from 1 to 2 (T1 -> T2), we need [1/scale, -shift/scale]

                cost = 1;

                if node_a_is_1
                    % We want A -> B, so 1 -> 2. (T1 -> T2)
                    % Since T1 = scale * T2 + shift
                    % T2 = (1/scale)*T1 - shift/scale
                    mapping = ndi.time.timemapping([1/scale -shift/scale]);
                else
                    % We want A -> B, so 2 -> 1. (T2 -> T1)
                    % T1 = scale * T2 + shift
                    mapping = ndi.time.timemapping([scale shift]);
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
