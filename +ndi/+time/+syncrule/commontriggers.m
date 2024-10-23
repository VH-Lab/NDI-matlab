classdef commontriggers < ndi.time.syncrule

    properties (SetAccess=protected,GetAccess=public),
    end % properties
    properties (SetAccess=protected,GetAccess=protected)
    end % properties
    methods
        function ndi_syncrule_commontriggers_obj = commontriggers(varargin)
            % NDI_SYNCRULE_COMMONTRIGGERS_OBJ - create a new ndi.time.syncrule.commontriggers for managing synchronization
            %
            % NDI_SYNCRULE_COMMONTRIGGERS_OBJ = ndi.time.syncrule.commontriggers()
            %      or
            % NDI_SYNCRULE_COMMONTRIGGERS_OBJ = ndi.time.syncrule.commontriggers(PARAMETERS)
            %
            % Creates a new ndi.time.syncrule.commontriggers object with the given PARAMETERS (a structure, see below).
            % If no inputs are provided, then the default PARAMETERS (see below) is used.
            %
            % PARAMETERS should be a structure with the following entries:
            % Field (default)              | Description
            % -------------------------------------------------------------------
            % daqsystem1                   | The name of the first daq system
            % channel_daq1                 | The channel on the first daq system
            % daqsystem2                   | The name of the second daq system
            % channel_daq2                 | The channel on the second daq system
            % number_fullpath_matches      | Number fullpath file matches that need to be true to check channels
            %
            error(['not ready yet.']);
            if nargin==0,
                parameters = struct('number_fullpath_matches', 2);
                varargin = {parameters};
            end
            ndi_syncrule_commontriggers_obj = ndi_syncrule_commontriggers_obj@ndi.time.syncrule(varargin{:});
        end

        function [b,msg] = isvalidparameters(ndi_syncrule_commontriggers_obj, parameters)
            % ISVALIDPARAMETERS - determine if a parameter structure is valid for a given ndi.time.syncrule.commontriggers
            %
            % [B,MSG] = ISVALIDPARAMETERS(NDI_SYNCRULE_COMMONTRIGGERS_OBJ, PARAMETERS)
            %
            % Returns 1 if PARAMETERS is a valid parameter structure for ndi.time.syncrule.commontriggers.
            % Returns 0 otherwise.
            %
            % If there is an error, MSG contains an error message.
            %
            % PARAMETERS should be a structure with the following entries:
            % Field (default)              | Description
            % -------------------------------------------------------------------
            % number_fullpath_matches (2)  | The number of full path matches of the underlying
            %                              |  filenames that must match in order for the epochs to match.
            %
            % See also: ndi.time.syncrule/SETPARAMETERS

            [b,msg] = vlt.data.hasAllFields(parameters,{'number_fullpath_matches'}, {[1 1]});
            if b,
                if ~isnumeric(parameters.number_fullpath_matches),
                    b = 0;
                    msg = 'number_fullpath_matches must be a number.';
                end
            end
            return;
        end % isvalidparameters

        function ees = eligibleepochsets(ndi_syncrule_commontriggers_obj)
            % ELIGIBLEEPOCHSETS - return a cell array of eligible ndi.epoch.epochset class names for ndi.time.syncrule.commontriggers
            %
            % EES = ELIGIBLEEPOCHSETS(NDI_SYNCRULE_COMMONTRIGGERS_OBJ)
            %
            % Returns a cell array of valid ndi.epoch.epochset subclasses that the rule can process.
            %
            % If EES is empty, then no information is conveyed about which ndi.epoch.epochset subtypes can be
            % processed by the ndi.time.syncrule.commontriggers. (That is, it is not the case that the NDI_SYNCTABLE cannot use any classes.)
            %
            % ndi.time.syncrule.commontriggers returns {'ndi.daq.system'} (it works with ndi.daq.system objects).
            %
            % NDI_EPOCHSETS that use the rule must be members or descendents of the classes returned here.
            %
            % See also: ndi.time.syncrule.commontriggers/INELIGIBLEEPOCHSETS
            ees = {'ndi.daq.system'}; %
        end % eligibleepochsets

        function ies = ineligibleepochsets(ndi_syncrule_commontriggers_obj)
            % INELIGIBLEEPOCHSETS - return a cell array of ineligible ndi.epoch.epochset class names for ndi.time.syncrule.commontriggers
            %
            % IES = INELIGIBLEEPOCHSETS(NDI_SYNCRULE_COMMONTRIGGERS_OBJ)
            %
            % Returns a cell array of ndi.epoch.epochset subclasses that the rule cannot process.
            %
            % If IES is empty, then no information is conveyed about which ndi.epoch.epochset subtypes cannot be
            % processed by the ndi.time.syncrule.commontriggers. (That is, it is not the case that the NDI_SYNCTABLE can use any class.)
            %
            % ndi.time.syncrule.commontriggers does not work with ndi.epoch.epochset, NDI_EPOCHSETPARAM, or ndi.file.navigator classes.
            %
            % NDI_EPOCHSETS that use the rule must not be members of the classes returned here, but may be descendents of those
            % classes.
            %
            % See also: ndi.time.syncrule.commontriggers/ELIGIBLEEPOCHSETS
            ies = cat(2,ndi_syncrule_commontriggers_obj.ineligibleepochsets@ndi.time.syncrule(),...
                {'ndi.epoch.epochset','ndi.epoch.epochset.param','ndi.file.navigator'});
        end % ineligibleepochsets

        function [cost,mapping] = apply(ndi_syncrule_commontriggers_obj, epochnode_a, epochnode_b)
            % APPLY - apply an ndi.time.syncrule.commontriggers to obtain a cost and ndi.time.timemapping between two ndi.epoch.epochset objects
            %
            % [COST, MAPPING] = APPLY(NDI_SYNCRULE_COMMONTRIGGERS_OBJ, EPOCHNODE_A, EPOCHNODE_B)
            %
            % Given an ndi.time.syncrule.commontriggers object and two EPOCHNODES (see ndi.epoch.epochset/EPOCHNODES),
            % this function attempts to identify whether a time synchronization can be made across these epochs. If so,
            % a cost COST and an ndi.time.timemapping object MAPPING is returned.
            %
            % Otherwise, COST and MAPPING are empty.
            %
            cost = [];
            mapping = [];

            % quick content checks
            eval(['dummy_a = ' epochnode_a.objectclass '();']);
            eval(['dummy_b = ' epochnode_b.objectclass '();']);
            if ~(isa(dummy_a,'ndi.daq.system')) | ~(isa(dummy_b,'ndi.daq.system')), return; end;
            if isempty(epochnode_a.underlying_epochs), return; end;
            if isempty(epochnode_b.underlying_epochs), return; end;
            if isempty(epochnode_a.underlying_epochs.underlying), return; end;
            if isempty(epochnode_b.underlying_epochs.underlying), return; end;
            % okay, proceed

            common = intersect(epochnode_a.underlying_epochs.underlying,epochnode_b.underlying_epochs.underlying);
            if numel(common)>=ndi_syncrule_commontriggers_obj.parameters.number_fullpath_matches,
                cost = 1;
                mapping = ndi.time.timemapping([1 0]); % equality
            end
        end % apply

    end % methods
end % classdef ndi.time.syncrule.commontriggers

