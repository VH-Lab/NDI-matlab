classdef syncrule < ndi.ido & ndi.documentservice

        properties (SetAccess=protected,GetAccess=public),
		parameters;        % parameters, a structure
        end % properties
        properties (SetAccess=protected,GetAccess=protected)
        end % properties
        methods
		function ndi_syncrule_obj = syncrule(varargin)
			% NDI_SYNCRULE_OBJ - create a new NDI_SYNCRULE for managing synchronization
			%
			% NDI_SYNCRULE_OBJ = ndi.time.syncrule(...)
			%  or
			% NDI_SYNCRULE_OBJ = ndi.time.syncrule(PARAMETERS)
			%
			% Creates a new ndi.time.syncrule object with the given PARAMETERS (a structure).
			% This is an abstract class, so PARAMETERS must be empty.
			%
				parameters = [];
				if nargin==2 & isa(varargin{1},'ndi.session') & isa(varargin{2},'ndi.document'),
					parameters = varargin{2}.document_properties.syncrule.parameters;
					ndi_syncrule_obj.identifier = varargin{2}.document_properties.base.id;
				elseif nargin >0,
					parameters = varargin{1};
				end;

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
				if b,
					ndi_syncrule_obj.parameters = parameters;
				else,
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

		function [cost,mapping] = apply(ndi_syncrule_obj, epochnode_a, epochnode_b)
			% APPLY - apply an ndi.time.syncrule to obtain a cost and ndi.time.timemapping between two ndi.epoch.epochset objects
			%
			% [COST, MAPPING] = APPLY(NDI_SYNCRULE_OBJ, EPOCHNODE_A, EPOCHNODE_B)
			%
			% Given an ndi.time.syncrule object and two epochnodes returned from ndi.epoch.epochset/EPOCHNODES
			% this function attempts to identify whether a time synchronization can be made across
			% these epoch nodes. If so, a cost COST and an ndi.time.timemapping object MAPPING is returned.
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
				ndi_document_obj = ndi.document('daq/syncrule',...
					'syncrule.ndi_syncrule_class',class(ndi_syncrule_obj),...
					'base.id', ndi_syncrule_obj.id(),...
					'syncrule.parameters', ndi_syncrule_obj.parameters);
		end; % newdocument()

		function sq = searchquery(ndi_syncrule_obj)
			% SEARCHQUERY - create a search for this ndi.time.syncrule object
			%
			% SQ = SEARCHQUERY(NDI_SYNCRULE_OBJ)
			%
			% Creates a search query for the ndi.time.syncgraph object.
			%
				sq = ndi.query({'base.id', ndi_syncrule_obj.id() });
		end; % searchquery()

	end % methods
end % classdef ndi.time.syncrule
