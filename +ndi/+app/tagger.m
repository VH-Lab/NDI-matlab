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
					doc = ndi.document('apps/tagger/tag','tag',tag) + ...
						ndi_app_tagger_obj.newdocument(); % add app info for this document
					doc = doc.set_dependency_value('document_id',tagged_doc_id);	
				else,
					error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
				end;
		end; % struct2doc()

		function appdoc_struct = doc2struct(ndi_app_tagger_obj, appdoc_type, doc)
			% DOC2STRUCT - create an ndi.document from an input structure and input parameters
			%
			% DOC = STRUCT2DOC(NDI_APPDOC_OBJ, SESSION, APPDOC_TYPE, APPDOC_STRUCT, [additional parameters]
			%
			% Create an ndi.document from a data structure APPDOC_STRUCT. The ndi.document is created
			% according to the APPDOC_TYPE of the NDI_APPDOC_OBJ.
			%
			% In the base class, this uses the property info in the ndi.document to load the data structure.
			%
				% first, call superclass method
				appdoc_struct = doc2struct@ndi.app.appdoc(ndi_app_tagger_obj, appdoc_type, doc);
				% then, add on tagged_doc_id, which has the form of a dependency instead of being in the 'tag' structure
				if strcmpi(appdoc_type,'tag'),
					appdoc_struct.tagged_doc_id = doc.dependency_value('document_id');
				end;
		end; % doc2struct()

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
					fields_needed = {'ontology','ontology_name','ontology_id','value','tagged_doc_id'};
					sizes_needed = { [1 -1],[1 -1],[1 -1], [-1 -1],[1 -1]};
					[b,errormsg] = vlt.data.hasAllFields(appdoc_struct,fields_needed,sizes_needed);
					if b, % if we are still good
						doc_exists = ndi_app_tagger_obj.session.database_search(ndi.query('ndi_document.id','exact_string',appdoc_struct.tagged_doc_id,''));
						if isempty(doc_exists),
							b = 0;
							errormsg = ['No such document with id ' appdoc_struct.tagged_doc_id '.'];
						end;
					end;
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
								q = q & ndi.query('','depends_on','document_id',tagged_doc_id);
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
			%   DOC = ADD_APPDOC(NDI_APP_TAGGER_OBJ, 'tag', TAG_STRUCT, DOCEXISTSACTION)
			%
			%   Creates a new tag document to the ndi.document.
			%
			%   TAG_STRUCT should be a structure with the following fields:
			%   Fieldname                       | Description
			%   --------------------------------|-------------------------------------------------------
			%   ontology ('')                   | Name of the ontology where `ontology_name` and 
			%                                   |   `ontology_id` are defined.
			%   ontology_name ('')              | The name of a word in `ontology` that is to be used as a tag
			%   ontology_id ('')                | The ID of the word in `ontology` that is to be used as a tag
			%   value ('')                      | The value of the tag (only appropriate for some tags).
			%
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


		function [docs] = struct2tags(ndi_app_tagger_obj, tagstruct, docExistAction)
			% STRUCT2TAGS - create a set of tag objects from a structure, usually read from a tab-separated value file
			%
			% [DOCS] = STRUCT2TAGS(NDI_APP_TAGGER_OBJ, TAGSTRUCT, DOCEXISTACTION)
			%
			% Adds tag documents to a given session using information specified in a structure TAGSTRUCT.
			% (The session is the session property of NDI_APP_TAGGER_OBJ.) DOCEXISTACTION describes
			% the action to take if the tag document already exists; it is one of 'Error', 'NoAction',
			% 'Replace', or 'ReplaceIfDifferent' (see help ndi.app.appdoc.add_appdoc).
			% DOCS is a cell array of ndi documents that are added.
			%
			% TAGSTRUCT should have the following fields:
			% ------------------------------------------------------------------------
			% Fieldname            | Description                                    
			% ------------------------------------------------------------------------
			% 'doc'                | Either the ID of an ndi.document in the sessions'
			%                      |   - or -
			%                      | the string query:STR where STR is an input to
			%                      |   ndi.query.string2query(STR). If a _single_
			%                      |   document is returned, then that document is
			%                      |   tagged. Otherwise, an error is generated.
			% 'ontology'           | The ontology for the tag document
			% 'ontology_name'      | The name of the tag (word in the ontology)
			% 'ontology_id'        | The ID of the word in the ontology
			% 'value'              | The value of the tag (if any)
			%
			%
				error(['I am not tested yet.']);
				[g,e] = vlt.data.hasAllFields(tagstruct(1),...
					{'doc','ontology','ontology_name','ontology_id','value'},...
					[1 -1],[1 -1],[1 -1],[1 -1],[-1 -1]);

				if ~g,
					error(['Bad tagstruct input: ' e ]);
				end;

				docs = {};
				appdoc_struct = vlt.data.emptystruct('tagged_doc_id','ontology','ontology_name','ontology_id','value');
					
				for i=1:numel(tagstruct),
						% check for query
					if strncmpi(tagstruct(i).doc,'query:'),
						qstr = tagstruct(i).doc(7:end);
						q = ndi.query.string2query(qstr);
					else, % assume it is a doc ID
						qstr = strtrim(tagstruct(i).doc);
						q = ndi.query('ndi_document.id','exact_string',qstr,'');
					end;
					d = ndi_app_tagger_obj.session.database_search(q);
					if numel(d)==0,
						error(['No documents found matching ' qstr '.']);
					elseif numel(d)>1,
						error(['Multiple documents ' int2str(numel(d)) ' found matching ' qstr '. Must only be 1.']);
					end;
					% now we can continue
					appdoc_struct_here.tagged_doc_id = d{1}.id();
					appdoc_struct_here.ontology = tagstruct(i).ontology;
					appdoc_struct_here.ontology_name = tagstruct(i).ontology_name;
					appdoc_struct_here.ontology_id = tagstruct(i).ontology_id;
					appdoc_struct_here.value= tagstruct(i).value;
					appdoc_struct(i) = appdoc_struct_here;
				end;
				% now that we have safetly verified the parameters of the inputs, we will add the docs
				for i=1:numel(appdoc_struct),
					docs{i} = ndi_app_tagger_obj.add_appdoc(appdoc_struct(i),docExistAction);
				end;
		end; % struct2tags()

	end; % methods

end % ndi_app_tagger
