classdef nsd_syncrule < nsd_base

        properties (SetAccess=protected,GetAccess=public),
		parameters;        % parameters, a structure
        end % properties
        properties (SetAccess=protected,GetAccess=protected)
        end % properties
        methods
		function nsd_syncrule_obj = nsd_syncrule(varargin)
			% NSD_SYNCRULE_OBJ - create a new NSD_SYNCRULE for managing synchronization
			%
			% NSD_SYNCRULE_OBJ = NSD_SYNCRULE(...)
			%  or
			% NSD_SYNCRULE_OBJ = NSD_SYNCRULE(PARAMETERS)
			%
			% Creates a new NSD_SYNCRULE object with the given PARAMETERS (a structure).
			% This is an abstract class, so PARAMETERS must be empty.
			%
				parameters = [];
				if nargin >0,
					parameters = varargin{1};
				end;
				nsd_syncrule_obj = setparameters(nsd_syncrule_obj,parameters);
		end

		function nsd_syncrule_obj = setparameters(nsd_syncrule_obj, parameters)
			% SETPARAMETERS - set the parameters for an NSD_SYNCRULE object, checking for valid form
			%
			% NSD_SYNCRULE_OBJ = SETPARAMETERS(NSD_SYNCRULE_OBJ, PARAMETERS)
			%
			% Sets the 'parameters' field of an NSD_SYNCRULE object, while also checking that
			% the struct PARAMETERS specifies a valid set of parameters using ISVALIDPARAMETERS.
			%
			% See also: NSD_SYNCRULE/ISVALIDPARAMETERS
			%
				if nsd_syncrule_obj.isvalidparameters(parameters),
					nsd_syncrule_obj.parameters = parameters;
				else,
					error(['Could not set parameters: ' msg ]); 
				end
		end % setparameters

		function [b,msg] = isvalidparameters(nsd_syncrule_obj, parameters)
			% ISVALIDPARAMETERS - determine if a parameter structure is valid for a given NSD_SYNCRULE
			%
			% [B,MSG] = ISVALIDPARAMETERS(NSD_SYNCRULE_OBJ, PARAMETERS)
			%
			% Returns 1 if PARAMETERS is a valid parameter structure for NSD_SYNCRULE. Returns 0 otherwise.
			%
			% If there is an error, MSG describes the error.
			%
			% See also: NSD_SYNCRULE/SETPARAMETERS
				
				% developer note:
				%  Q:Why have this function? Why not just produce an error when applying the rule?
				%  A:Because syncrules are often set far in advance of being applied to data.
				%    It is an error one wants to see at the time of setting the rule.

				b = 1; 
				msg = '';
				return;
		end % isvalidparameters

		function ec = eligibleclocks(nsd_syncrule_obj)
			% ELIGIBLECLOCKS - return a cell array of eligible NSD_CLOCKTYPEs that can be used with NSD_SYNCRULE
			%
			% EC = ELIGIBLECLOCKS(NSD_SYNCRULE_OBJ)
			%
			% Returns a cell array of NSD_CLOCKTYPE objects with types that can be processed by the
			% NSD_SYNCRULE.
			%
			% If EC is empty, then no information is conveyed about which NSD_CLOCKTYPE objects
			% is valid (that is, it is not the case that the NSD_SYNCRULE processes no types; instead, it has no specific limits).
			%
			% In the abstract class, EC is empty ({}).
			%
			% See also: NSD_SYNCRULE/INELIGIBLECLOCKS
			%
				ec = {};
		end % eligibleclocks

		function ic = ineligibleclocks(nsd_syncrule_obj)
			% INELIGIBLECLOCKS - return a cell array of ineligible NSD_CLOCKTYPEs that cannot be used with NSD_SYNCRULE
			%
			% IC = INELIGIBLECLOCKS(NSD_SYNCRULE_OBJ)
			%
			% Returns a cell array of NSD_CLOCKTYPE objects with types that cannot be processed by the
			% NSD_SYNCRULE.
			%
			% If IC is empty, then no information is conveyed about which NSD_CLOCKTYPE objects
			% is valid (that is, it is not the case that the NSD_SYNCRULE cannot be used on any types; instead, it has
			% no specific limits).
			%
			% In the abstract class, IC is {nsd_clocktype('no_time')} .
			%
			% See also: NSD_SYNCRULE/ELIGIBLECLOCKS
			%
				ic = {nsd_clocktype('no_time')};
		end % ineligibleclocks

		function ees = eligibleepochsets(nsd_syncrule_obj)
			% ELIGIBLEEPOCHSETS - return a cell array of eligible NSD_EPOCHSET class names for NSD_SYNCRULE
			%
			% EES = ELIGIBLEEPOCHSETS(NSD_SYNCRULE_OBJ)
			%
			% Returns a cell array of valid NSD_EPOCHSET subclasses that the rule can process.
			%
			% If EES is empty, then no information is conveyed about which NSD_EPOCHSET subtypes can be
			% processed by the NSD_SYNCRULE. (That is, it is not the case that the NSD_SYNCTABLE cannot use any classes.)
			%
			% NSD_EPOCHSETS that use the rule must be members or descendents of the classes returned here.
			%
			% The abstract class NSD_SYNCRULE always returns empty.
			%
			% See also: NSD_SYNCRULE/INELIGIBLEEPOCHSETS
				ees = {}; % 
		end % eligibleepochsets

		function ies = ineligibleepochsets(nsd_syncrule_obj)
			% INELIGIBLEEPOCHSETS - return a cell array of ineligible NSD_EPOCHSET class names for NSD_SYNCRULE
			%
			% IES = INELIGIBLEEPOCHSETS(NSD_SYNCRULE_OBJ)
			%
			% Returns a cell array of NSD_EPOCHSET subclasses that the rule cannot process.
			%
			% If IES is empty, then no information is conveyed about which NSD_EPOCHSET subtypes cannot be
			% processed by the NSD_SYNCRULE. (That is, it is not the case that the NSD_SYNCTABLE can use any class.)
			%
			% NSD_EPOCHSETS that use the rule must not be members of the classes returned here, but may be descendents of those
			% classes.
			%
			% The abstract class NSD_SYNCRULE always returns empty.
			%
			% See also: NSD_SYNCRULE/ELIGIBLEEPOCHSETS
				ies = {}; % 
		end % ineligibleepochsets

		function [cost,mapping] = apply(nsd_syncrule_obj, nsd_epochset_obj_a, epochtable_a, nsd_epochset_obj_b, epochtable_b)
			% APPLY - apply an NSD_SYNCRULE to obtain a cost and NSD_TIMEMAPPING between two NSD_EPOCHSET objects
			%
			% [COST, MAPPING] = APPLY(NSD_SYNCRULE_OBJ, NSD_EPOCHEST_OBJ_A, EPOCHTABLE_A, ...
			%                       NSD_EPOCHSET_OBJ_B, EPOCHTABLE_B)
			%
			% Given an NSD_SYNCRULE object, two NSD_EPOCHSET objects a and b, and an epochtable entry of each,
			% this function attempts to identify whether a time synchronization can be made across these epochs. If so,
			% a cost COST and an NSD_TIMEMAPPING object MAPPING is returned.
			%
			% Otherwise, COST and MAPPING are empty.
			%
			% In the abstract class, COST and MAPPING are always empty.
				cost = [];
				mapping = [];
		end % apply

	end % methods
end % classdef nsd_syncrule
