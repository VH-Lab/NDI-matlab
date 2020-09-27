classdef ndi_syncrule_filematch < ndi_syncrule

        properties (SetAccess=protected,GetAccess=public),
        end % properties
        properties (SetAccess=protected,GetAccess=protected)
        end % properties
        methods
		function ndi_syncrule_filematch_obj = ndi_syncrule_filematch(varargin)
			% NDI_SYNCRULE_FILEMATCH_OBJ - create a new NDI_SYNCRULE_FILEMATCH for managing synchronization
			%
			% NDI_SYNCRULE_FILEMATCH_OBJ = NDI_SYNCRULE_FILEMATCH()
			%      or
			% NDI_SYNCRULE_FILEMATCH_OBJ = NDI_SYNCRULE_FILEMATCH(PARAMETERS)
			%
			% Creates a new NDI_SYNCRULE_FILEMATCH object with the given PARAMETERS (a structure, see below).
			% If no inputs are provided, then the default PARAMETERS (see below) is used.
			%
			% PARAMETERS should be a structure with the following entries:
			% Field (default)              | Description
			% -------------------------------------------------------------------
			% number_fullpath_matches (2)  | The number of full path matches of the underlying 
			%                              |  filenames that must match in order for the epochs to match.
			%
				if nargin==0,
					parameters = struct('number_fullpath_matches', 2);
					varargin = {parameters};
				end
				ndi_syncrule_filematch_obj = ndi_syncrule_filematch_obj@ndi_syncrule(varargin{:});
		end

		function [b,msg] = isvalidparameters(ndi_syncrule_filemath_obj, parameters)
			% ISVALIDPARAMETERS - determine if a parameter structure is valid for a given NDI_SYNCRULE_FILEMATCH
			%
			% [B,MSG] = ISVALIDPARAMETERS(NDI_SYNCRULE_FILEMATCH_OBJ, PARAMETERS)
			%
			% Returns 1 if PARAMETERS is a valid parameter structure for NDI_SYNCRULE_FILEMATCH.
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
			% See also: NDI_SYNCRULE/SETPARAMETERS

				[b,msg] = vlt.data.hasAllFields(parameters,{'number_fullpath_matches'}, {[1 1]});
				if b,
					if ~isnumeric(parameters.number_fullpath_matches),
						b = 0;
						msg = 'number_fullpath_matches must be a number.';
					end
				end
				return;
		end % isvalidparameters

		function ees = eligibleepochsets(ndi_syncrule_filematch_obj)
			% ELIGIBLEEPOCHSETS - return a cell array of eligible NDI_EPOCHSET class names for NDI_SYNCRULE_FILEMATCH
			%
			% EES = ELIGIBLEEPOCHSETS(NDI_SYNCRULE_FILEMATCH_OBJ)
			%
			% Returns a cell array of valid NDI_EPOCHSET subclasses that the rule can process.
			%
			% If EES is empty, then no information is conveyed about which NDI_EPOCHSET subtypes can be
			% processed by the NDI_SYNCRULE_FILEMATCH. (That is, it is not the case that the NDI_SYNCTABLE cannot use any classes.)
			%
			% NDI_SYNCRULE_FILEMATCH returns {'ndi_daqsystem'} (it works with NDI_DAQSYSTEM objects).
			%
			% NDI_EPOCHSETS that use the rule must be members or descendents of the classes returned here.
			%
			% See also: NDI_SYNCRULE_FILEMATCH/INELIGIBLEEPOCHSETS
				ees = {'ndi_daqsystem'}; % 
		end % eligibleepochsets

		function ies = ineligibleepochsets(ndi_syncrule_filematch_obj)
			% INELIGIBLEEPOCHSETS - return a cell array of ineligible NDI_EPOCHSET class names for NDI_SYNCRULE_FILEMATCH
			%
			% IES = INELIGIBLEEPOCHSETS(NDI_SYNCRULE_FILEMATCH_OBJ)
			%
			% Returns a cell array of NDI_EPOCHSET subclasses that the rule cannot process.
			%
			% If IES is empty, then no information is conveyed about which NDI_EPOCHSET subtypes cannot be
			% processed by the NDI_SYNCRULE_FILEMATCH. (That is, it is not the case that the NDI_SYNCTABLE can use any class.)
			%
			% NDI_SYNCRULE_FILEMATCH does not work with NDI_EPOCHSET, NDI_EPOCHSETPARAM, or NDI_FILENAVIGATOR classes.
			%
			% NDI_EPOCHSETS that use the rule must not be members of the classes returned here, but may be descendents of those
			% classes.
			%
			% See also: NDI_SYNCRULE_FILEMATCH/ELIGIBLEEPOCHSETS
				ies = cat(2,ndi_syncrule_filematch_obj.ineligibleepochsets@ndi_syncrule(),...
					{'ndi_epochset','ndi_epochsetparam','ndi_filenavigator'}); 
		end % ineligibleepochsets

		function [cost,mapping] = apply(ndi_syncrule_filematch_obj, epochnode_a, epochnode_b)
			% APPLY - apply an NDI_SYNCRULE_FILEMATCH to obtain a cost and NDI_TIMEMAPPING between two NDI_EPOCHSET objects
			%
			% [COST, MAPPING] = APPLY(NDI_SYNCRULE_FILEMATCH_OBJ, EPOCHNODE_A, EPOCHNODE_B)
			%
			% Given an NDI_SYNCRULE_FILEMATCH object and two EPOCHNODES (see NDI_EPOCHSET/EPOCHNODES),
			% this function attempts to identify whether a time synchronization can be made across these epochs. If so,
			% a cost COST and an NDI_TIMEMAPPING object MAPPING is returned.
			%
			% Otherwise, COST and MAPPING are empty.
			%
				cost = [];
				mapping = [];

				% quick content checks
				eval(['dummy_a = ' epochnode_a.objectclass '();']);
				eval(['dummy_b = ' epochnode_b.objectclass '();']);
				if ~(isa(dummy_a,'ndi_daqsystem')) | ~(isa(dummy_b,'ndi_daqsystem')), return; end;
				if isempty(epochnode_a.underlying_epochs), return; end; 
				if isempty(epochnode_b.underlying_epochs), return; end; 
				if isempty(epochnode_a.underlying_epochs.underlying), return; end; 
				if isempty(epochnode_b.underlying_epochs.underlying), return; end; 
				% okay, proceed

				common = intersect(epochnode_a.underlying_epochs.underlying,epochnode_b.underlying_epochs.underlying);
				if numel(common)>=ndi_syncrule_filematch_obj.parameters.number_fullpath_matches,
					cost = 1;
					mapping = ndi_timemapping([1 0]); % equality
				end
		end % apply

	end % methods
end % classdef ndi_syncrule_filematch

