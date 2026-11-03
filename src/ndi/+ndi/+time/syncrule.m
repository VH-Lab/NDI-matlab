classdef syncrule < ndi.ido & ndi.documentservice

    properties (SetAccess=protected,GetAccess=public)
        parameters;        % parameters, a structure
    end % properties
    properties (SetAccess=protected,GetAccess=protected)
    end % properties
    methods
        function ndi_syncrule_obj = syncrule(varargin)
            % SYNCRULE - create a new NDI_SYNCRULE for managing synchronization
            %
            % NDI_SYNCRULE_OBJ = ndi.time.syncrule(...)
            %  or
            % NDI_SYNCRULE_OBJ = ndi.time.syncrule(PARAMETERS)
            %
            % Creates a new ndi.time.syncrule object with the given PARAMETERS (a structure).
            % This is an abstract class, so PARAMETERS must be empty.
            %
            parameters = [];
            if nargin==2 & isa(varargin{1},'ndi.session') & isa(varargin{2},'ndi.document')
                % BOTH VINTAGES, and this one is not a rename. V_eta
                % EXPLODES the `parameters` bag: four entries become typed
                % fields on `clock_alignment_configuration`, the device
                % pair moves out into two `acquisition_channels`
                % documents, and `errorOnFailure` is dropped outright. The
                % v1 read below is what ndi.vintage.syncruleParameters
                % performs unchanged for a v1 document, so nothing about
                % the old path moves.
                %
                % `class(ndi_syncrule_obj)` is the CONCRETE SUBCLASS here
                % even though this is the superclass constructor, which is
                % what lets the reconstruction build the exact parameter
                % set that subclass's `isvalidparameters` demands.
                parameters = ndi.vintage.syncruleParameters(varargin{2}, ...
                    varargin{1}, class(ndi_syncrule_obj));
                ndi_syncrule_obj.identifier = varargin{2}.document_properties.base.id;
            elseif nargin >0
                parameters = varargin{1};
            end

            ndi_syncrule_obj = setparameters(ndi_syncrule_obj,parameters);
        end

        function ndi_syncrule_obj = setparameters(ndi_syncrule_obj, parameters)
            % SETPARAMETERS - set the parameters for an ndi.time.syncrule object, checking for valid form
            %
            % NDI_SYNCRULE_OBJ = SETPARAMETERS(NDI_SYNCRULE_OBJ, PARAMETERS)
            %
            % Sets the 'parameters' field of an ndi.time.syncrule object, while also checking that
            % the struct PARAMETERS specifies a valid set of parameters using ISVALIDPARAMETERS.
            %
            % See also: ndi.time.syncrule/ISVALIDPARAMETERS
            %
            [b,msg] = ndi_syncrule_obj.isvalidparameters(parameters);
            if b
                ndi_syncrule_obj.parameters = parameters;
            else
                error(['Could not set parameters: ' msg ]);
            end
        end % setparameters

        function [b,msg] = isvalidparameters(ndi_syncrule_obj, parameters)
            % ISVALIDPARAMETERS - determine if a parameter structure is valid for a given ndi.time.syncrule
            %
            % [B,MSG] = ISVALIDPARAMETERS(NDI_SYNCRULE_OBJ, PARAMETERS)
            %
            % Returns 1 if PARAMETERS is a valid parameter structure for ndi.time.syncrule. Returns 0 otherwise.
            %
            % If there is an error, MSG describes the error.
            %
            % See also: ndi.time.syncrule/SETPARAMETERS

            % developer note:
            %  Q:Why have this function? Why not just produce an error when applying the rule?
            %  A:Because syncrules are often set far in advance of being applied to data.
            %    It is an error one wants to see at the time of setting the rule.

            b = 1;
            msg = '';
            return;
        end % isvalidparameters

        function b = eq(ndi_syncrule_obj_a, ndi_syncrule_obj_b)
            % EQ - are two ndi.time.syncrule objects equal?
            %
            % B = EQ(NDI_SYNCRULE_OBJ_A, NDI_SYNCRULE_OBJ_B)
            %
            % Returns 1 if the parameters of NDI_SYNCRULE_OBJ_A and NDI_SYNCRULE_OBJ_B are equal.
            % Otherwise, 0 is returned.
            b = vlt.data.eqlen(ndi_syncrule_obj_a.parameters,ndi_syncrule_obj_b.parameters);
        end % eq()

        function ec = eligibleclocks(ndi_syncrule_obj)
            % ELIGIBLECLOCKS - return a cell array of eligible NDI_CLOCKTYPEs that can be used with ndi.time.syncrule
            %
            % EC = ELIGIBLECLOCKS(NDI_SYNCRULE_OBJ)
            %
            % Returns a cell array of ndi.time.clocktype objects with types that can be processed by the
            % ndi.time.syncrule.
            %
            % If EC is empty, then no information is conveyed about which ndi.time.clocktype objects
            % is valid (that is, it is not the case that the ndi.time.syncrule processes no types; instead, it has no specific limits).
            %
            % In the abstract class, EC is empty ({}).
            %
            % See also: ndi.time.syncrule/INELIGIBLECLOCKS
            %
            ec = {};
        end % eligibleclocks

        function ic = ineligibleclocks(ndi_syncrule_obj)
            % INELIGIBLECLOCKS - return a cell array of ineligible NDI_CLOCKTYPEs that cannot be used with ndi.time.syncrule
            %
            % IC = INELIGIBLECLOCKS(NDI_SYNCRULE_OBJ)
            %
            % Returns a cell array of ndi.time.clocktype objects with types that cannot be processed by the
            % ndi.time.syncrule.
            %
            % If IC is empty, then no information is conveyed about which ndi.time.clocktype objects
            % is valid (that is, it is not the case that the ndi.time.syncrule cannot be used on any types; instead, it has
            % no specific limits).
            %
            % In the abstract class, IC is {ndi.time.clocktype('no_time')} .
            %
            % See also: ndi.time.syncrule/ELIGIBLECLOCKS
            %
            ic = {ndi.time.clocktype('no_time')};
        end % ineligibleclocks

        function ees = eligibleepochsets(ndi_syncrule_obj)
            % ELIGIBLEEPOCHSETS - return a cell array of eligible ndi.epoch.epochset class names for ndi.time.syncrule
            %
            % EES = ELIGIBLEEPOCHSETS(NDI_SYNCRULE_OBJ)
            %
            % Returns a cell array of valid ndi.epoch.epochset subclasses that the rule can process.
            %
            % If EES is empty, then no information is conveyed about which ndi.epoch.epochset subtypes can be
            % processed by the ndi.time.syncrule. (That is, it is not the case that the NDI_SYNCTABLE cannot use any classes.)
            %
            % NDI_EPOCHSETS that use the rule must be members or descendents of the classes returned here.
            %
            % The abstract class ndi.time.syncrule always returns empty.
            %
            % See also: ndi.time.syncrule/INELIGIBLEEPOCHSETS
            ees = {}; %
        end % eligibleepochsets

        function ies = ineligibleepochsets(ndi_syncrule_obj)
            % INELIGIBLEEPOCHSETS - return a cell array of ineligible ndi.epoch.epochset class names for ndi.time.syncrule
            %
            % IES = INELIGIBLEEPOCHSETS(NDI_SYNCRULE_OBJ)
            %
            % Returns a cell array of ndi.epoch.epochset subclasses that the rule cannot process.
            %
            % If IES is empty, then no information is conveyed about which ndi.epoch.epochset subtypes cannot be
            % processed by the ndi.time.syncrule. (That is, it is not the case that the NDI_SYNCTABLE can use any class.)
            %
            % NDI_EPOCHSETS that use the rule must not be members of the classes returned here, but may be descendents of those
            % classes.
            %
            % The abstract class ndi.time.syncrule always returns empty.
            %
            % See also: ndi.time.syncrule/ELIGIBLEEPOCHSETS
            ies = {}; %
        end % ineligibleepochsets

        function [cost,mapping] = apply(ndi_syncrule_obj, epochnode_a, epochnode_b, daqsystem1)
            % APPLY - apply an ndi.time.syncrule to obtain a cost and ndi.time.timemapping between two ndi.epoch.epochset objects
            %
            % [COST, MAPPING] = APPLY(NDI_SYNCRULE_OBJ, EPOCHNODE_A, EPOCHNODE_B, DAQSYSTEM1)
            %
            % Given an ndi.time.syncrule object and two epochnodes returned from ndi.epoch.epochset/EPOCHNODES
            % this function attempts to identify whether a time synchronization can be made across
            % these epoch nodes. If so, a cost COST and an ndi.time.timemapping object MAPPING is returned.
            %
            % DAQSYSTEM1 is the ndi.daq.system object corresponding to EPOCHNODE_A.
            %
            % Otherwise, COST and MAPPING are empty.
            %
            % In the abstract class, COST and MAPPING are always empty.
            %
            % See also: ndi.epoch.epochset/EPOCHNODES
            %
            cost = [];
            mapping = [];
        end % apply

        %% functions that override ndi.documentservice

        function ndi_document_obj = newdocument(ndi_syncrule_obj)
            % NEWDOCUMENT - create a new ndi.document for an ndi.time.syncrule object
            %
            % DOC = NEWDOCUMENT(NDI_SYNCRULE_OBJ)
            %
            % Creates an ndi.document object DOC that represents the
            %    ndi.time.syncrule object.
            ndi_document_obj = ndi.document('syncrule',...
                'syncrule.ndi_syncrule_class',class(ndi_syncrule_obj),...
                'base.id', ndi_syncrule_obj.id(),...
                'base.session_id',ndi.session.empty_id(),...
                'syncrule.parameters', ndi_syncrule_obj.parameters);
        end % newdocument()

        function [docs, carriedWhy] = newdocumentV2(ndi_syncrule_obj, ndi_session_obj)
            % NEWDOCUMENTV2 - the V2 record of this rule, for a V2 database
            %
            % [DOCS, CARRIEDWHY] = NEWDOCUMENTV2(NDI_SYNCRULE_OBJ, NDI_SESSION_OBJ)
            %
            % Returns the rule as DID-matlab's +migrators_j/syncrule.m (with
            % its second pass, did2.convert.resolveClockAlignment) writes a
            % v1 `syncrule`, in the session NDI_SESSION_OBJ (whose database
            % is V2, ndi.session/writesV2):
            %
            %   {clock_alignment_configuration, software entity}, as
            %   ndi.document objects. The configuration's id is the rule's
            %   id; `software_id` names a `software` entity whose `name` is
            %   the rule's class; the rule's settings are its method
            %   parameters ('minimum matching file paths', 'sync file name',
            %   'minimum embedded file overlap', 'from trigger channel',
            %   'to trigger channel', and every other setting under its own
            %   name); `clock` is its epochclocktype; and a rule that names
            %   two daq systems (filefind, commonTriggersOverlappingEpochs,
            %   randomPulses) links them as `from_acquisition_system_id`
            %   (daqsystem1) and `to_acquisition_system_id` (daqsystem2)
            %   (Jess Haley 2026-10-27 [sync configuration links its rigs],
            %   [sync rule direction is recorded]). This is the shape
            %   ndi.vintage.syncruleParameters reads back.
            %
            % Where the migration carries a rule whole as v1, so does this,
            % and CARRIEDWHY says why ('' when the rule is written as V2);
            % DOCS is then {NEWDOCUMENT(NDI_SYNCRULE_OBJ)}, the v1 document
            % unchanged:
            %   - a rule class NDI cannot rebuild from a configuration
            %     (ndi.vintage.syncruleParameters knows filematch, filefind,
            %     commonTriggersOverlappingEpochs and randomPulses);
            %   - a named daq system that is not exactly one acquisition
            %     system in the session (resolveClockAlignment refuses
            %     rather than invents);
            %   - a setting that cannot be written (a number that is not
            %     finite: [small unread settings] (3));
            %   - a term did2.build refuses because the term registry does
            %     not hold it (Jess Haley 2026-10-26 [early migration pieces
            %     fixed] (3): an unregistered term becomes a carry until the
            %     registry holds it).
            %
            % See also: ndi.time.syncgraph/newdocument,
            %   ndi.vintage.syncruleParameters
            arguments
                ndi_syncrule_obj (1,1) ndi.time.syncrule
                ndi_session_obj (1,1) ndi.session
            end
            carriedWhy = '';
            cls = class(ndi_syncrule_obj);
            p = ndi_syncrule_obj.parameters;
            if ~isstruct(p) || ~isscalar(p)
                p = struct();
            end
            switch cls
                case 'ndi.time.syncrule.filefind'
                    nameKeys = {'daqsystem1', 'daqsystem2'};
                case {'ndi.time.syncrule.commonTriggersOverlappingEpochs', ...
                        'ndi.time.syncrule.randomPulses'}
                    nameKeys = {'daqsystem1_name', 'daqsystem2_name'};
                case 'ndi.time.syncrule.filematch'
                    nameKeys = {};
                otherwise
                    carriedWhy = sprintf(['%s: no V2 configuration is defined for this ' ...
                        'rule class (ndi.vintage.syncruleParameters could not rebuild it)'], cls);
                    docs = {ndi_syncrule_obj.newdocument()};
                    return;
            end
            sid = ndi_session_obj.id();

            % the two daq systems, by name, within the session
            systemIds = {};
            for k = 1:numel(nameKeys)
                [systemIds{k}, why] = systemIdByName(ndi_session_obj, ...
                    textParameter(p, nameKeys{k})); %#ok<AGROW>
                if isempty(systemIds{k})
                    carriedWhy = sprintf('%s.%s: %s', cls, nameKeys{k}, why);
                    docs = {ndi_syncrule_obj.newdocument()};
                    return;
                end
            end

            % the settings, in the order the migrator writes them
            entries = {};
            consumed = reshape(nameKeys, 1, []);
            if isfield(p, 'number_fullpath_matches') && isnumeric(p.number_fullpath_matches) ...
                    && isscalar(p.number_fullpath_matches) && isfinite(p.number_fullpath_matches)
                entries{end+1} = {'minimum matching file paths', 'Count', ...
                    double(p.number_fullpath_matches)};
                consumed{end+1} = 'number_fullpath_matches';
            end
            if ~isempty(textParameter(p, 'syncfilename'))
                entries{end+1} = {'sync file name', 'Text', textParameter(p, 'syncfilename')};
                consumed{end+1} = 'syncfilename';
            end
            if isfield(p, 'minEmbeddedFileOverlap') && isnumeric(p.minEmbeddedFileOverlap) ...
                    && isscalar(p.minEmbeddedFileOverlap) && isfinite(p.minEmbeddedFileOverlap)
                entries{end+1} = {'minimum embedded file overlap', 'Value', ...
                    double(p.minEmbeddedFileOverlap)};
                consumed{end+1} = 'minEmbeddedFileOverlap';
            end
            channels = {'daqsystem_ch1', 'from trigger channel'; 'daqsystem_ch2', 'to trigger channel'};
            for k = 1:size(channels, 1)
                if ~isempty(textParameter(p, channels{k, 1}))
                    entries{end+1} = {channels{k, 2}, 'Text', textParameter(p, channels{k, 1})}; %#ok<AGROW>
                    consumed{end+1} = channels{k, 1}; %#ok<AGROW>
                end
            end
            clockName = textParameter(p, 'epochclocktype');
            if ~isempty(clockName)
                consumed{end+1} = 'epochclocktype';
            end
            % every other setting under its own name ([small unread settings])
            rest = setdiff(fieldnames(p), consumed, 'stable');
            for k = 1:numel(rest)
                v = p.(rest{k});
                if isempty(v)
                    continue;
                elseif (isnumeric(v) || islogical(v)) && isscalar(v)
                    if ~isfinite(double(v))
                        carriedWhy = sprintf('%s.%s: a number that is not finite', cls, rest{k});
                        docs = {ndi_syncrule_obj.newdocument()};
                        return;
                    end
                    entries{end+1} = {strrep(rest{k}, '_', ' '), 'Value', double(v), ...
                        'SourceValue', shortestText(double(v))}; %#ok<AGROW>
                elseif ischar(v) && isrow(v)
                    entries{end+1} = {strrep(rest{k}, '_', ' '), 'Text', v}; %#ok<AGROW>
                elseif isstring(v) && isscalar(v)
                    entries{end+1} = {strrep(rest{k}, '_', ' '), 'Text', char(v)}; %#ok<AGROW>
                else
                    entries{end+1} = {strrep(rest{k}, '_', ' '), 'Text', char(jsonencode(v))}; %#ok<AGROW>
                end
            end

            try
                sw = ndi.setup.V2.entityDocuments('software', ...
                    struct('name', cls, 'local_identifier', cls), struct(), 'SessionId', sid);
                f = struct();
                if ~isempty(clockName)
                    f.clock = ndi.v2.vocabTerm('clock', clockName);
                end
                if ~isempty(entries)
                    built = cellfun(@(e) did2.build.parameter( ...
                        ndi.setup.V2.registeredTerm('', e{1}), e{2:end}), entries, ...
                        'UniformOutput', false);
                    f.method = struct('parameters', did2.build.list(built{:}));
                end
                edges = struct('software_id', sw{1}.base.id);
                if ~isempty(systemIds)
                    edges.from_acquisition_system_id = systemIds{1};
                    edges.to_acquisition_system_id = systemIds{2};
                end
                cfg = did2.build.document('clock_alignment_configuration', f, ...
                    'Edges', edges, 'Id', ndi_syncrule_obj.id(), 'SessionId', sid);
            catch ME
                if ~strcmp(ME.identifier, 'did2:build:unregisteredTerm')
                    rethrow(ME);
                end
                carriedWhy = sprintf('%s: %s', cls, ME.message);
                docs = {ndi_syncrule_obj.newdocument()};
                return;
            end
            docs = [{ndi.document(cfg)}, cellfun(@(x) ndi.document(x), sw, 'UniformOutput', false)];
        end % newdocumentV2()

        function sq = searchquery(ndi_syncrule_obj)
            % SEARCHQUERY - create a search for this ndi.time.syncrule object
            %
            % SQ = SEARCHQUERY(NDI_SYNCRULE_OBJ)
            %
            % Creates a search query for the ndi.time.syncgraph object.
            %
            sq = ndi.query({'base.id', ndi_syncrule_obj.id() });
        end % searchquery()

    end % methods
end % classdef ndi.time.syncrule

function v = textParameter(p, name)
% TEXTPARAMETER - P.(NAME) as char when it is non-empty text, else ''
v = '';
if isfield(p, name)
    x = p.(name);
    if ischar(x) && (isrow(x) || isempty(x))
        v = x;
    elseif isstring(x) && isscalar(x)
        v = char(x);
    end
end
end % textParameter()

function [id, why] = systemIdByName(ndi_session_obj, name)
% SYSTEMIDBYNAME - the id of the one daq system named NAME in the session
%
% ID is '' (and WHY says why) when no system, or more than one, has that
% name: DID-matlab's did2.convert.resolveClockAlignment refuses a missing or
% an ambiguous name rather than inventing a system or taking the first.
id = '';
why = '';
if isempty(name)
    why = 'no daq system is named';
    return;
end
docs = ndi_session_obj.database_search(ndi.vintage.isaQuery('daqsystem') & ...
    ndi.query('base.session_id', 'exact_string', ndi_session_obj.id(), ''));
hit = cellfun(@(d) strcmp(ndi.vintage.objectName(d), name), docs);
switch nnz(hit)
    case 1
        id = docs{find(hit, 1)}.id();
    case 0
        why = sprintf('no daq system named ''%s'' is in the session', name);
    otherwise
        why = sprintf('%d daq systems are named ''%s'' in the session', nnz(hit), name);
end
end % systemIdByName()

function t = shortestText(x)
% SHORTESTTEXT - the shortest decimal text that reads back as X
for n = 1:17
    t = sprintf('%.*g', n, x);
    if str2double(t) == x
        return;
    end
end
end % shortestText()
