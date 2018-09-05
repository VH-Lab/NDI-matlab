classdef nsd_syncrule_filematch < nsd_syncrule

        properties (SetAccess=protected,GetAccess=public),
        end % properties
        properties (SetAccess=protected,GetAccess=protected)
        end % properties
        methods
		function nsd_syncrule_filematch_obj = nsd_syncrule_filematch(varargin)
			% NSD_SYNCRULE_FILEMATCH_OBJ - create a new NSD_SYNCRULE_FILEMATCH for managing synchronization
			%
			% NSD_SYNCRULE_FILEMATCH_OBJ = NSD_SYNCRULE_FILEMATCH()
			%      or
			% NSD_SYNCRULE_FILEMATCH_OBJ = NSD_SYNCRULE_FILEMATCH(PARAMETERS)
			%
			% Creates a new NSD_SYNCRULE_FILEMATCH object with the given PARAMETERS (a structure, see below).
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
				else,
					parameters = varargin{1};
				end
				nsd_syncrule_filematch_obj = nsd_syncrule_filematch_obj@nsd_syncrule(parameters);
		end

		function [b,msg] = isvalidparameters(nsd_syncrule_filemath_obj, parameters)
			% ISVALIDPARAMETERS - determine if a parameter structure is valid for a given NSD_SYNCRULE_FILEMATCH
			%
			% [B,MSG] = ISVALIDPARAMETERS(NSD_SYNCRULE_FILEMATCH_OBJ, PARAMETERS)
			%
			% Returns 1 if PARAMETERS is a valid parameter structure for NSD_SYNCRULE_FILEMATCH.
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
			% See also: NSD_SYNCRULE/SETPARAMETERS

				[b,msg] = hasAllFields(parameters,{'number_fullpath_matches'}, {[1 1]});
				if b,
					if ~isnumeric(parameters.number_fullpath_matches),
						b = 0;
						msg = 'number_fullpath_matches must be a number.';
					end
				end
				return;
		end % isvalidparameters

		function ees = eligibleepochsets(nsd_syncrule_filematch_obj)
			% ELIGIBLEEPOCHSETS - return a cell array of eligible NSD_EPOCHSET class names for NSD_SYNCRULE_FILEMATCH
			%
			% EES = ELIGIBLEEPOCHSETS(NSD_SYNCRULE_FILEMATCH_OBJ)
			%
			% Returns a cell array of valid NSD_EPOCHSET subclasses that the rule can process.
			%
			% If EES is empty, then no information is conveyed about which NSD_EPOCHSET subtypes can be
			% processed by the NSD_SYNCRULE_FILEMATCH. (That is, it is not the case that the NSD_SYNCTABLE cannot use any classes.)
			%
			% NSD_SYNCRULE_FILEMATCH returns {'nsd_iodevice'} (it works with NSD_IODEVICE objects).
			%
			% NSD_EPOCHSETS that use the rule must be members or descendents of the classes returned here.
			%
			% See also: NSD_SYNCRULE_FILEMATCH/INELIGIBLEEPOCHSETS
				ees = {'nsd_iodevice'}; % 
		end % eligibleepochsets

		function ies = ineligibleepochsets(nsd_syncrule_filematch_obj)
			% INELIGIBLEEPOCHSETS - return a cell array of ineligible NSD_EPOCHSET class names for NSD_SYNCRULE_FILEMATCH
			%
			% IES = INELIGIBLEEPOCHSETS(NSD_SYNCRULE_FILEMATCH_OBJ)
			%
			% Returns a cell array of NSD_EPOCHSET subclasses that the rule cannot process.
			%
			% If IES is empty, then no information is conveyed about which NSD_EPOCHSET subtypes cannot be
			% processed by the NSD_SYNCRULE_FILEMATCH. (That is, it is not the case that the NSD_SYNCTABLE can use any class.)
			%
			% NSD_SYNCRULE_FILEMATCH does not work with NSD_EPOCHSET, NSD_EPOCHSETPARAM, or NSD_FILETREE classes.
			%
			% NSD_EPOCHSETS that use the rule must not be members of the classes returned here, but may be descendents of those
			% classes.
			%
			% See also: NSD_SYNCRULE_FILEMATCH/ELIGIBLEEPOCHSETS
				ies = cat(2,nsd_syncrule_filematch_obj.ineligibleepochsets@nsd_syncrule(),...
					{'nsd_epochset','nsd_epochsetparam','nsd_filetree'}); 
		end % ineligibleepochsets

		function [cost,mapping] = apply(nsd_syncrule_filematch_obj, nsd_epochset_class_a, epochnode_a, nsd_epochset_class_b, epochnode_b)
			% APPLY - apply an NSD_SYNCRULE_FILEMATCH to obtain a cost and NSD_TIMEMAPPING between two NSD_EPOCHSET objects
			%
			% [COST, MAPPING] = APPLY(NSD_SYNCRULE_FILEMATCH_OBJ, NSD_EPOCHEST_CLASS_A, EPOCHNODE_A, ...
			%                       NSD_EPOCHSET_CLASS_B, EPOCHNODE_B)
			%
			% Given an NSD_SYNCRULE_FILEMATCH object, two NSD_EPOCHSET class types, and an epochnode entry of each,
			% this function attempts to identify whether a time synchronization can be made across these epochs. If so,
			% a cost COST and an NSD_TIMEMAPPING object MAPPING is returned.
			%
			% Otherwise, COST and MAPPING are empty.
			%
				cost = [];
				mapping = [];

				% quick content checks
				eval(['dummy_a = ' nsd_epochset_class_a '();']);
				eval(['dummy_b = ' nsd_epochset_class_b '();']);
				if ~isa(dummy_a,'nsd_iodevice') | ~isa(dummy_b,'nsd_iodevice'), return; end;
				if isempty(epochtable_a.underlying_epochs), return; end; 
				if isempty(epochtable_b.underlying_epochs), return; end; 
				if isempty(epochtable_a.underlying_epochs.underlying), return; end; 
				if isempty(epochtable_b.underlying_epochs.underlying), return; end; 

				% okay, proceed

				common = intersect(epochtable_a.underlying_epochs.underlying,epochtable_b.underlying_epochs.underlying);
				if numel(common)>=nsd_syncrule_filematch_obj.parameters.number_fullpath_matches,
					cost = 1;
					mapping = nsd_timemapping([1 0]); % equality
				end
		end % apply

	end % methods
end % classdef nsd_syncrule_filematch

