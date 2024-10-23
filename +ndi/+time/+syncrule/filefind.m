classdef filefind < ndi.time.syncrule

    properties (SetAccess=protected,GetAccess=public),
    end % properties
    properties (SetAccess=protected,GetAccess=protected)
    end % properties
    methods
        function ndi_syncrule_filefind_obj = filefind(varargin)
            % NDI_SYNCRULE_FILEFIND_OBJ - create a new ndi.time.syncrule.filefind for managing synchronization
            %
            % NDI_SYNCRULE_FILEFIND_OBJ = ndi.time.syncrule.filefind()
            %      or
            % NDI_SYNCRULE_FILEFIND_OBJ = ndi.time.syncrule.filefind(PARAMETERS)
            %
            % Creates a new ndi.time.syncrule.filefind object with the given PARAMETERS (a structure, see below).
            % If no inputs are provided, then the default PARAMETERS (see below) is used.
            %
            % PARAMETERS should be a structure with the following entries:
            % Field (default)              | Description
            % -------------------------------------------------------------------
            % number_fullpath_matches (1)  | The number of full path matches of the underlying
            %                              |  filenames that must match in order for the epochs to match.
            % syncfilename ('syncfile.txt')| The text synchronization file to find
            %                              |  This file should have 2 numbers in it; a shift and a scale.
            %                              |  TimeOnDaqSystem2 = shift + scale * TimeOnDaqSystem1
            %                              |  This file should be in the second daq system's epoch files.
            % daqsystem1 ('mydaq1')        | The name of the first daq system
            % daqsystem2 ('mydaq2')        | The name of the second daq system
            %
            %
            if nargin==0,
                parameters = struct('number_fullpath_matches', 1, ...
                    'syncfilename','syncfile.txt',...
                    'daqsystem1','mydaq1','daqsystem2','mydaq2');
                varargin = {parameters};
            end
            ndi_syncrule_filefind_obj = ndi_syncrule_filefind_obj@ndi.time.syncrule(varargin{:});
        end

        function [b,msg] = isvalidparameters(ndi_syncrule_filefind_obj, parameters)
            % ISVALIDPARAMETERS - determine if a parameter structure is valid for a given ndi.time.syncrule.filefind
            %
            % [B,MSG] = ISVALIDPARAMETERS(NDI_SYNCRULE_FILEFIND_OBJ, PARAMETERS)
            %
            % Returns 1 if PARAMETERS is a valid parameter structure for ndi.time.syncrule.filefind.
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
            [b,msg] = vlt.data.hasAllFields(parameters,{'number_fullpath_matches','syncfilename','daqsystem1','daqsystem2'}, {[1 1],[1 -1],[1 -1],[1 -1]});
            if b,
                if ~isnumeric(parameters.number_fullpath_matches),
                    b = 0;
                    msg = 'number_fullpath_matches must be a number.';
                end
                if ~ischar(parameters.syncfilename),
                    b = 0;
                    msg = 'syncfilename must be a character string';
                end;
                if ~ischar(parameters.daqsystem1),
                    b = 0;
                    msg = 'daqsystem1 must be a character string';
                end;
                if ~ischar(parameters.daqsystem2),
                    b = 0;
                    msg = 'daqsystem2 must be a character string';
                end;
            end
        end % isvalidparameters

        function ees = eligibleepochsets(ndi_syncrule_filefind_obj)
            % ELIGIBLEEPOCHSETS - return a cell array of eligible ndi.epoch.epochset class names for ndi.time.syncrule.filefind
            %
            % EES = ELIGIBLEEPOCHSETS(NDI_SYNCRULE_FILEFIND_OBJ)
            %
            % Returns a cell array of valid ndi.epoch.epochset subclasses that the rule can process.
            %
            % If EES is empty, then no information is conveyed about which ndi.epoch.epochset subtypes can be
            % processed by the ndi.time.syncrule.filefind. (That is, it is not the case that the NDI_SYNCTABLE cannot use any classes.)
            %
            % ndi.time.syncrule.filefind returns {'ndi.daq.system'} (it works with ndi.daq.system objects).
            %
            % NDI_EPOCHSETS that use the rule must be members or descendents of the classes returned here.
            %
            % See also: ndi.time.syncrule.filefind/INELIGIBLEEPOCHSETS
            ees = {'ndi.daq.system'}; %
        end % eligibleepochsets

        function ies = ineligibleepochsets(ndi_syncrule_filefind_obj)
            % INELIGIBLEEPOCHSETS - return a cell array of ineligible ndi.epoch.epochset class names for ndi.time.syncrule.filefind
            %
            % IES = INELIGIBLEEPOCHSETS(NDI_SYNCRULE_FILEFIND_OBJ)
            %
            % Returns a cell array of ndi.epoch.epochset subclasses that the rule cannot process.
            %
            % If IES is empty, then no information is conveyed about which ndi.epoch.epochset subtypes cannot be
            % processed by the ndi.time.syncrule.filefind. (That is, it is not the case that the NDI_SYNCTABLE can use any class.)
            %
            % ndi.time.syncrule.filefind does not work with ndi.epoch.epochset, NDI_EPOCHSETPARAM, or ndi.file.navigator classes.
            %
            % NDI_EPOCHSETS that use the rule must not be members of the classes returned here, but may be descendents of those
            % classes.
            %
            % See also: ndi.time.syncrule.filefind/ELIGIBLEEPOCHSETS
            ies = cat(2,ndi_syncrule_filefind_obj.ineligibleepochsets@ndi.time.syncrule(),...
                {'ndi.epoch.epochset','ndi.epoch.epochset.param','ndi.file.navigator'});
        end % ineligibleepochsets

        function [cost,mapping] = apply(ndi_syncrule_filefind_obj, epochnode_a, epochnode_b)
            % APPLY - apply an ndi.time.syncrule.filefind to obtain a cost and ndi.time.timemapping between two ndi.epoch.epochset objects
            %
            % [COST, MAPPING] = APPLY(NDI_SYNCRULE_FILEFIND_OBJ, EPOCHNODE_A, EPOCHNODE_B)
            %
            % Given an ndi.time.syncrule.filefind object and two EPOCHNODES (see ndi.epoch.epochset/EPOCHNODES),
            % this function attempts to identify whether a time synchronization can be made across these epochs. If so,
            % a cost COST and an ndi.time.timemapping object MAPPING is returned.
            %
            % Otherwise, COST and MAPPING are empty.
            %
            cost = [];
            mapping = [];

            % quick content checks
            forward = strcmp(epochnode_a.objectname,ndi_syncrule_filefind_obj.parameters.daqsystem1) & ...
                strcmp(epochnode_b.objectname,ndi_syncrule_filefind_obj.parameters.daqsystem2);
            backward = strcmp(epochnode_b.objectname,ndi_syncrule_filefind_obj.parameters.daqsystem1) & ...
                strcmp(epochnode_a.objectname,ndi_syncrule_filefind_obj.parameters.daqsystem2);
            % these epochnodes do not come from the daq systems we know how to sync
            if ~forward & ~backward,
                return;
            end;
            eval(['dummy_a = ' epochnode_a.objectclass '();']);
            eval(['dummy_b = ' epochnode_b.objectclass '();']);
            if ~(isa(dummy_a,'ndi.daq.system')) | ~(isa(dummy_b,'ndi.daq.system')), return; end;
            if isempty(epochnode_a.underlying_epochs), return; end;
            if isempty(epochnode_b.underlying_epochs), return; end;
            if isempty(epochnode_a.underlying_epochs.underlying), return; end;
            if isempty(epochnode_b.underlying_epochs.underlying), return; end;
            % okay, proceed

            common = intersect(epochnode_a.underlying_epochs.underlying,epochnode_b.underlying_epochs.underlying);
            if numel(common)>=ndi_syncrule_filefind_obj.parameters.number_fullpath_matches,
                % we can proceed
                cost = 1;

                % now, this can happen one of two ways. We can map from a->b or b->a

                % here is a->b
                if forward,
                    for i=1:numel(epochnode_a.underlying_epochs.underlying),
                        [filepath,filename,fileext] = fileparts(epochnode_a.underlying_epochs.underlying{i});
                        if strcmp([filename fileext],ndi_syncrule_filefind_obj.parameters.syncfilename), % match!
                            syncdata = load(epochnode_a.underlying_epochs.underlying{i},'-ascii');
                            shift = syncdata(1);
                            scale = syncdata(2);
                            mapping = ndi.time.timemapping([scale shift]);
                            return;
                        end;
                    end;
                    error(['No file matched ' ndi_syncrule_filefind_obj.parameters.syncfilename '.']);
                end;

                % here is b->a

                if backward,
                    for i=1:numel(epochnode_b.underlying_epochs.underlying),
                        [filepath,filename,fileext] = fileparts(epochnode_b.underlying_epochs.underlying{i});
                        if strcmp([filename fileext],ndi_syncrule_filefind_obj.parameters.syncfilename), % match!
                            syncdata = load(epochnode_b.underlying_epochs.underlying{i},'-ascii');
                            shift = syncdata(1);
                            scale = syncdata(2);
                            shift_reverse = -shift/scale;
                            scale_reverse = 1/scale;
                            mapping = ndi.time.timemapping([scale_reverse shift_reverse]);
                            return;
                        end;
                    end;
                    error(['No file matched ' ndi_syncrule_filefind_obj.parameters.syncfilename '.']);
                end;
            end
        end % apply
    end % methods
end % classdef ndi.time.syncrule.filefind

