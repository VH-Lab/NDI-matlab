classdef ndi_syncrule < ndi_id & ndi_documentservice

        properties (SetAccess=protected,GetAccess=public),
		parameters;        % parameters, a structure
        end % properties
        properties (SetAccess=protected,GetAccess=protected)
        end % properties
        methods
		function ndi_syncrule_obj = ndi_syncrule(varargin)
			% NDI_SYNCRULE_OBJ - create a new NDI_SYNCRULE for managing synchronization
			%
			% NDI_SYNCRULE_OBJ = NDI_SYNCRULE(...)
			%  or
			% NDI_SYNCRULE_OBJ = NDI_SYNCRULE(PARAMETERS)
			%
			% Creates a new NDI_SYNCRULE object with the given PARAMETERS (a structure).
			% This is an abstract class, so PARAMETERS must be empty.
			%
				parameters = [];
				if nargin==2 & isa(varargin{1},'ndi_session') & isa(varargin{2},'ndi_document'),
					parameters = varargin{2}.document_properties.syncrule.parameters;
					ndi_syncrule_obj.identifier = varargin{2}.document_properties.ndi_document.id;
				elseif nargin >0,
					parameters = varargin{1};
				end;

				ndi_syncrule_obj = setparameters(ndi_syncrule_obj,parameters);
		end

		function ndi_syncrule_obj = setparameters(ndi_syncrule_obj, parameters)
			% SETPARAMETERS - set the parameters for an NDI_SYNCRULE object, checking for valid form
			%
			% NDI_SYNCRULE_OBJ = SETPARAMETERS(NDI_SYNCRULE_OBJ, PARAMETERS)
			%
			% Sets the 'parameters' field of an NDI_SYNCRULE object, while also checking that
			% the struct PARAMETERS specifies a valid set of parameters using ISVALIDPARAMETERS.
			%
			% See also: NDI_SYNCRULE/ISVALIDPARAMETERS
			%
				[b,msg] = ndi_syncrule_obj.isvalidparameters(parameters);
				if b,
					ndi_syncrule_obj.parameters = parameters;
				else,
					error(['Could not set parameters: ' msg ]); 
				end
		end % setparameters

		function [b,msg] = isvalidparameters(ndi_syncrule_obj, parameters)
			% ISVALIDPARAMETERS - determine if a parameter structure is valid for a given NDI_SYNCRULE
			%
			% [B,MSG] = ISVALIDPARAMETERS(NDI_SYNCRULE_OBJ, PARAMETERS)
			%
			% Returns 1 if PARAMETERS is a valid parameter structure for NDI_SYNCRULE. Returns 0 otherwise.
			%
			% If there is an error, MSG describes the error.
			%
			% See also: NDI_SYNCRULE/SETPARAMETERS
				
				% developer note:
				%  Q:Why have this function? Why not just produce an error when applying the rule?
				%  A:Because syncrules are often set far in advance of being applied to data.
				%    It is an error one wants to see at the time of setting the rule.

				b = 1; 
				msg = '';
				return;
		end % isvalidparameters

		function b = eq(ndi_syncrule_obj_a, ndi_syncrule_obj_b)
			% EQ - are two NDI_SYNCRULE objects equal?
			%
			% B = EQ(NDI_SYNCRULE_OBJ_A, NDI_SYNCRULE_OBJ_B)
			%
			% Returns 1 if the parameters of NDI_SYNCRULE_OBJ_A and NDI_SYNCRULE_OBJ_B are equal.
			% Otherwise, 0 is returned.
				b = vlt.data.eqlen(ndi_syncrule_obj_a.parameters,ndi_syncrule_obj_b.parameters);
		end % eq()

		function ec = eligibleclocks(ndi_syncrule_obj)
			% ELIGIBLECLOCKS - return a cell array of eligible NDI_CLOCKTYPEs that can be used with NDI_SYNCRULE
			%
			% EC = ELIGIBLECLOCKS(NDI_SYNCRULE_OBJ)
			%
			% Returns a cell array of NDI_CLOCKTYPE objects with types that can be processed by the
			% NDI_SYNCRULE.
			%
			% If EC is empty, then no information is conveyed about which NDI_CLOCKTYPE objects
			% is valid (that is, it is not the case that the NDI_SYNCRULE processes no types; instead, it has no specific limits).
			%
			% In the abstract class, EC is empty ({}).
			%
			% See also: NDI_SYNCRULE/INELIGIBLECLOCKS
			%
				ec = {};
		end % eligibleclocks

		function ic = ineligibleclocks(ndi_syncrule_obj)
			% INELIGIBLECLOCKS - return a cell array of ineligible NDI_CLOCKTYPEs that cannot be used with NDI_SYNCRULE
			%
			% IC = INELIGIBLECLOCKS(NDI_SYNCRULE_OBJ)
			%
			% Returns a cell array of NDI_CLOCKTYPE objects with types that cannot be processed by the
			% NDI_SYNCRULE.
			%
			% If IC is empty, then no information is conveyed about which NDI_CLOCKTYPE objects
			% is valid (that is, it is not the case that the NDI_SYNCRULE cannot be used on any types; instead, it has
			% no specific limits).
			%
			% In the abstract class, IC is {ndi_clocktype('no_time')} .
			%
			% See also: NDI_SYNCRULE/ELIGIBLECLOCKS
			%
				ic = {ndi_clocktype('no_time')};
		end % ineligibleclocks

		function ees = eligibleepochsets(ndi_syncrule_obj)
			% ELIGIBLEEPOCHSETS - return a cell array of eligible NDI_EPOCHSET class names for NDI_SYNCRULE
			%
			% EES = ELIGIBLEEPOCHSETS(NDI_SYNCRULE_OBJ)
			%
			% Returns a cell array of valid NDI_EPOCHSET subclasses that the rule can process.
			%
			% If EES is empty, then no information is conveyed about which NDI_EPOCHSET subtypes can be
			% processed by the NDI_SYNCRULE. (That is, it is not the case that the NDI_SYNCTABLE cannot use any classes.)
			%
			% NDI_EPOCHSETS that use the rule must be members or descendents of the classes returned here.
			%
			% The abstract class NDI_SYNCRULE always returns empty.
			%
			% See also: NDI_SYNCRULE/INELIGIBLEEPOCHSETS
				ees = {}; % 
		end % eligibleepochsets

		function ies = ineligibleepochsets(ndi_syncrule_obj)
			% INELIGIBLEEPOCHSETS - return a cell array of ineligible NDI_EPOCHSET class names for NDI_SYNCRULE
			%
			% IES = INELIGIBLEEPOCHSETS(NDI_SYNCRULE_OBJ)
			%
			% Returns a cell array of NDI_EPOCHSET subclasses that the rule cannot process.
			%
			% If IES is empty, then no information is conveyed about which NDI_EPOCHSET subtypes cannot be
			% processed by the NDI_SYNCRULE. (That is, it is not the case that the NDI_SYNCTABLE can use any class.)
			%
			% NDI_EPOCHSETS that use the rule must not be members of the classes returned here, but may be descendents of those
			% classes.
			%
			% The abstract class NDI_SYNCRULE always returns empty.
			%
			% See also: NDI_SYNCRULE/ELIGIBLEEPOCHSETS
				ies = {}; % 
		end % ineligibleepochsets

		function [cost,mapping] = apply(ndi_syncrule_obj, epochnode_a, epochnode_b)
			% APPLY - apply an NDI_SYNCRULE to obtain a cost and NDI_TIMEMAPPING between two NDI_EPOCHSET objects
			%
			% [COST, MAPPING] = APPLY(NDI_SYNCRULE_OBJ, EPOCHNODE_A, EPOCHNODE_B)
			%
			% Given an NDI_SYNCRULE object and two epochnodes returned from NDI_EPOCHSET/EPOCHNODES
			% this function attempts to identify whether a time synchronization can be made across
			% these epoch nodes. If so, a cost COST and an NDI_TIMEMAPPING object MAPPING is returned.
			%
			% Otherwise, COST and MAPPING are empty.
			%
			% In the abstract class, COST and MAPPING are always empty.
			%
			% See also: NDI_EPOCHSET/EPOCHNODES
			%
				cost = [];
				mapping = [];
		end % apply

		%% functions that override ndi_documentservice

		function ndi_document_obj = newdocument(ndi_syncrule_obj)
			% NEWDOCUMENT - create a new NDI_DOCUMENT for an NDI_SYNCRULE object
			%
			% DOC = NEWDOCUMENT(NDI_SYNCRULE_OBJ)
			%
			% Creates an NDI_DOCUMENT object DOC that represents the
			%    NDI_SYNCRULE object.
				ndi_document_obj = ndi_document('ndi_document_syncrule.json',...
					'syncrule.ndi_syncrule_class',class(ndi_syncrule_obj),...
					'ndi_document.id', ndi_syncrule_obj.id(),...
					'syncrule.parameters', ndi_syncrule_obj.parameters);
		end; % newdocument()

		function sq = searchquery(ndi_syncrule_obj)
			% SEARCHQUERY - create a search for this NDI_SYNCRULE object
			%
			% SQ = SEARCHQUERY(NDI_SYNCRULE_OBJ)
			%
			% Creates a search query for the NDI_SYNCGRAPH object.
			%
				sq = {'ndi_document.id', ndi_syncrule_obj.id() };
		end; % searchquery()

	end % methods
end % classdef ndi_syncrule
