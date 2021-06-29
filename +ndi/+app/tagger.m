classdef tagger < ndi.app & ndi.app.appdoc

	properties (SetAccess=protected,GetAccess=public)

	end % properties

	methods

		function ndi_app_tagger_obj = tagger (varargin)
			% ndi.app.tagger - an app to tag ndi documents with labels
			%
			% NDI_APP_TAGGER_OBJ = ndi.app.tagger(SESSION)
			%
			% Creates a new ndi_app_tagger object that can operate on
			% NDI_SESSIONS. The app is named 'ndi_app_tagger'.
			%
				session = [];
				name = 'ndi_app_tagger';
				if numel(varargin)>0,
					session = varargin{1};
				end
				
				ndi_app_tagger_obj = ndi_app_tagger_obj@ndi.app(session, name);
				ndi_app_tagger_obj = ndi_app_tagger_obj@ndi.app.appdoc(...
					{'tag'}, {'apps/tagger/tag'}, session);

		end % ndi_app_tagger() creator

		% functions that override ndi_app_appdoc

		function doc = struct2doc(ndi_app_tagger_obj, appdoc_type, appdoc_struct, varargin)
			% STRUCT2DOC - create an ndi.document from an input structure and input parameters
			%
			% DOC = STRUCT2DOC(NDI_APP_TAGGER_OBJ, APPDOC_TYPE, APPDOC_STRUCT, ...)
			%
			% For ndi_app_tagger, one can use an APPDOC_TYPE of the following:
			% APPDOC_TYPE                 | Description
			% ----------------------------------------------------------------------------------------------
			% 'tag'                       | A document that provides the ability to "tag" any NDI document
			%                             |    with a name and value that are in a named ontology
			%
			% See APPDOC_DESCRIPTION for a list of the parameters.
			% 
				if strcmpi(appdoc_type,'tag'),
					tagged_doc_id = appdoc_struct.tagged_doc_id;
					tag = rmfield(appdoc_struct,'tagged_doc_id');
					if numel(varargin) >=1, 
						tag.ontology = varargin{1};
					else,
						error(['tag document needs ONTOLOGY.']);
					end;
					if numel(varargin) >=2,
						tag.ontology_name = varargin{2};
					else,
						error(['tag document needs ONTOLOGY_NAME.']);
					end;
					if numel(varargin) >=3,
						tag.ontology_id = varargin{3};
					else,
						error(['tag document needs ONTOLOGY_ID.']);
					end;
					tag.ontology_value = '';
					if numel(varargin) >=4,
						tag.ontology_value = varargin{4};
					end;
					doc = ndi.document('apps/tagger/tag','tag',tag) + ...
						ndi_app_tagger_obj.newdocument(); % add app info for this document
					doc = doc.set_dependency_value('document_id',tagged_doc_id);	
				else,
					error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
				end;

		end; % struct2doc()

		function [b,errormsg] = isvalid_appdoc_struct(ndi_app_tagger_obj, appdoc_type, appdoc_struct)
			% ISVALID_APPDOC_STRUCT - is an input structure a valid descriptor for an APPDOC?
			%
			% [B,ERRORMSG] = ISVALID_APPDOC_STRUCT(NDI_APP_TAGGER_OBJ, APPDOC_TYPE, APPDOC_STRUCT)
			%
			% Examines APPDOC_STRUCT and determines whether it is a valid input for creating an
			% ndi.document described by APPDOC_TYPE. B is 1 if it is valid and 0 otherwise.
			%
			% For ndi_app_tagger, one can use an APPDOC_TYPE of the following:
			% APPDOC_TYPE               | Description
			% ----------------------------------------------------------------------------------------------
			% 'tag'                     | A document that describes the parameters to be used for extraction
			%
				errormsg = '';
				if strcmpi(appdoc_type,'tag'),
					b = 1; % punt on this right now
				else,
					error(['Unknown appdoc_type ' appdoc_type '.']);
				end;

		end; % isvalid_appdoc_struct()

                function doc = find_appdoc(ndi_app_tagger_obj, appdoc_type, varargin)
                        % FIND_APPDOC - find an ndi_app_appdoc document in the session database
                        %
			% See ndi_app_tagger/APPDOC_DESCRIPTION for documentation.
			%
			% See also: ndi_app_tagger/APPDOC_DESCRIPTION
			%
        			switch(lower(appdoc_type)),
					case 'tag',
						q = ndi.query('','isa','tag','');
						tagged_doc_id = '';
						if numel(varargin) >= 1,
							% if a tagged_doc_id is provided, include it in the search
							tagged_doc_id = varargin{1};
							if ~isempty(tagged_doc_id),
								q = q & ndi.query('','depends_on',tagged_doc_id,'');
							end;
						end;
						ontology = '';
						if numel(varargin) >= 2,
							ontology = varargin{2};
							if ~isempty(ontology),
								q = q & ndi.query('tag.ontology','exact_string',ontology,'');
							end;
						end;
						ontology_name = '';
						if numel(varargin) >= 3,
							ontology_name = varargin{3};
							if ~isempty(ontology_name),
								q = q & ndi.query('tag.ontology_name','exact_string',ontology_name,'');
							end;
						end;
						ontology_id = '';
						if numel(varargin) >= 4,
							ontology_id = varargin{4};
							if ~isempty(ontology_id),
								q = q & ndi.query('tag.ontology_id','exact_string',ontology_id,'');
							end;
						end;
						ontology_value_search = '';
						if numel(varargin) >=5,
							ontology_value_search = varargin{4};
							ontology_value_search_op = 'exact_string';
							if numel(varargin) >=6, 
								ontology_value_search_op = varargin{6};
							end;
							if ~isempty(ontology_value_search),
								q = q & ndi.query('tag.ontology_value',ontology_value_search_op,ontology_value_search,'');
							end;
						end;
						doc = ndi_app_tagger_obj.session.database_search(q);
					otherwise,
						error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
					end; % switch
		end; % find_appdoc

		function varargout = loaddata_appdoc(ndi_app_tagger_obj, appdoc_type, varargin)
			% LOADDATA_APPDOC - load data from an application document
			%
			% See ndi_app_tagger/APPDOC_DESCRIPTION for documentation.
			%
			% See also: ndi_app_tagger/APPDOC_DESCRIPTION
			%
				varargout = ndi_app_tagger_obj.find_appdoc(appdoc_type,varargin{:});
		end; % loaddata_appdoc()

		function appdoc_description(ndi_app_appdoc_obj)
			% APPDOC_DESCRIPTION - a function that prints a description of all appdoc types
			%
			% For ndi_app_tagger, there are the following types:
			% APPDOC_TYPE                 | Description
			% ----------------------------------------------------------------------------------------------
			% 'tag'                       | A document that provides the ability to "tag" any NDI document 
			%                             |    with a name and value that are in a named ontology
			% ----------------------------------------------------------------------------------------------
			%
			% ----------------------------------------------------------------------------------------------
			% APPDOC 1: TAG
			% ----------------------------------------------------------------------------------------------
			%
			%   ----------------
			%   | TAG -- ABOUT | 
			%   ----------------
			%
			%   TAG documents provide an association between a name and value that are codified as part of an
			%   ontology and an NDI document.
			%
			%   Definition: app/tagger/tag
			%
			%   -------------------
			%   | TAG -- CREATION | 
			%   -------------------
			%
			%   DOC = ADD_APPDOC(NDI_APP_TAGGER_OBJ, 'tag', STRUCT, DOCEXISTSACTION, ...
			%        ONTOLOGY, ONTOLOGY_NAME, ONTOLOGY_ID, ONTOLOGY_VALUE)
			%
			%   Creates a new tag document to the ndi.document. STRUCT should be a structure with a single field
			%   'tagged_doc_ID'. The tag document is created with ID TAGGED_DOC_ID, from the ontology
			%   ONTOLOGY, and with the name ONTOLOGY_NAME and id ONTOLOGY_ID and an optional value ONTOLOGY_VALUE.
			%   ONTOLOGY_NAME and ONTOLOGY_ID should be the name and id string of a valid word in the given ontology.
			%   ONTOLOGY can be blank, in which case ONTOLOGY_NAME is just a name provided by the user.
			%   DOCEXISTSACTION is the action to be taken when a document already exists and should be 'Error', 'NoAction',
			%   'Replace', or 'ReplaceIfDifferent' (see help ndi.app.appdoc.add_appdoc)
			%
			%   ------------------
			%   | TAG -- FINDING |
			%   ------------------
			%
			%   [TAG_DOC_ARRAY] = FIND_APPDOC(NDI_APP_TAGGER_OBJ, 'tag', TAGGED_DOC_ID, ...
			%        [ONTOLOGY, ONTOLOGY_NAME, ONTOLOGY_ID, ONTOLOGY_VALUE_SEARCH, ONTOLOGY_VALUE_SEARCH_OP])
			%
			%   INPUTS: 
			%     TAGGED_DOC_ID - the ID of the NDI document that is tagged (may be empty to search for all matches)
			%     ONTOLOGY - the name of an ONTOLOGY to search for (may be be empty to search for all ontologies)
			%     ONTOLOGY_NAME - the name of an ONTOLOGY word to search for (may be empty to search for all names)
			%     ONTOLOGY_ID - the id of the word in ONTOLOGY to search for (may be empty to search for all names)
			%     ONTOLOGY_VALUE_SEARCH - a search term for ONTOLOGY_VALUE (may be empty to search for all values)
			%     ONTOLOGY_VALUE_SEARCH_OP - the search operation to use, see help ndi.query
			%   OUPUT: 
			%     Returns all matching documents in a cell array TAG_DOC_ARRAY
			%
			%   ------------------
			%   | TAG -- LOADING |
			%   ------------------
			%
			%   [TAG_DOC_ARRAY] = LOADDATA_APPDOC(NDI_APP_TAGGER_OBJ, 'tag', TAGGED_DOC_ID, ...
			%        [ONTOLOGY, ONTOLOGY_NAME, ONTOLOGY_ID, ONTOLOGY_VALUE_SEARCH, ONTOLOGY_VALUE_SEARCH_OP])
			%
			%   (Same inputs, outputs as FIND_APPDOC. There is no data to load with tags.)
			%
				eval(['help ndi_app_tagger/appdoc_description']); 
		end; % appdoc_description()

	end; % methods

end % ndi_app_tagger
