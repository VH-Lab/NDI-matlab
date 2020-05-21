classdef ndi_subject < ndi_id & ndi_documentservice
% NDI_SUBJECT - the subject of a measurement or stimulation
%

	properties (GetAccess=public, SetAccess=protected)
		local_identifier	% A string that is a local identifier in the lab, e.g. anteater23@nosuchlab.org
		description             % A string description
	end; % properties

	methods

		function ndi_subject_obj = ndi_subject(varargin)
			% NDI_SUBJECT - create a new NDI_SUBJECT object
			%
			% NDI_SUBJECT_OBJ = NDI_SUBJECT(LOCAL_IDENTIFIER, DESCRIPTION)
			%   or
			% NDI_SUBJECT_OBJ = NDI_SUBJECT(NDI_SESSION_OBJ, NDI_SUBJECT_DOCUMENT)
			%
			% Creates an NDI_SUBJECT object, either from a local identifier name or 
			% an NDI_SESSION object and an NDI_DOCUMENT that describes the NDI_SUBJECT object.
			%
			% 
				local_identifier_ = '';
				description_ = '';
				
				if numel(varargin==2),
					E = varargin{1};
					if ~isa(E,'ndi_session'),
						local_identifier_ = varargin{1};
						[b,msg] = ndi_subject.isvalidlocalidentifierstring(local_identifier_);
						if ~b,
							error(msg);
						end;
						description_ = varargin{2};
						if ~ischar(description_)
							error(['description must be a string.']);
						end;
					else,
						if ~isa(E,'ndi_session'),
							error(['First input argument must be an NDI_SESSION input']);
						end;
						if ~isa(varargin{2},'ndi_document'),
							subject_search = E.database_search(ndi_query('ndi_document.id',...
								'exact_string',varargin{2},''));
							if numel(subject_search)~=1,
								error(['When 2 input arguments are given, 2nd input must be an NDI_DOCUMENT or document ID.']);
							end;
							subject_doc = subject_search{1};
						else,
							subject_doc = varargin{2};
						end;
						local_identifier_ = subject_doc.document_properties.subject.local_identifer;
						description_ = subject_doc.document_properties.subject.description;
					end;
				end;
				ndi_subject_obj.local_identifier = local_identifier_;
				ndi_subject_obj.description = description_;
		end; % ndi_subject()

		%%% NDI_DOCUMENTSERVICE methods

		function ndi_document_obj = newdocument(ndi_subject_obj)
			% NEWDOCUMENT - return a new database document of type NDI_DOCUMENT based on a subject
			%
			% NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_SUBJECT_OBJ)
			%
			% Creates a new NDI_DOCUMENT of type 'ndi_document_subject'.
			%
				ndi_document_obj = ndi_document('ndi_document_subject',...
					'subject.local_identifier', ndi_subject_obj.local_identifier,...
					'subject.description', ndi_subject_obj.description,...
					'ndi_document.id', ndi_subject_obj.id());

		end; % newdocument()

		function sq = searchquery(ndi_subject_obj)
			% SEARCHQUERY - return a search query for an NDI_DOCUMENT based on this element
			%
			% SQ = SEARCHQUERY(NDI_SUBJECT_OBJ)
			%
			%
				sq = {'subject.local_identifier',ndi_subject.local_identifer'};
		end; % searchquery()

	end; % methods

	methods (Static) % static methods

		function [b,msg] = isvalidlocalidentifierstring(local_identifier)
			% ISVALIDLOCALIDENTIFIERSTRING - is this a valid local identifier string?
			%
			% [B,MSG] = ISVALIDLOCALIDENTIFIERSTRING(LOCAL_IDENTIFIER)
			%
			% Returns 1 if the input LOCAL_IDENTIFIER is a character string and
			% if it has an '@' in it. If B is 0, then an error message string is returned
			% in MSG.
				b = 1; msg = '';
				if ~ischar(local_identifier),
					msg = 'local_identifier must be a character string';
					b = 0;
				end;
				if ~any(local_identifier=='@'),
					msg = 'local_identifier must have an @ character.';
					b = 0;
				end;
		end; % isvalidlocalidentifierstring()

		function [b,subject_id] = does_subjectstring_match_session_document(ndi_session_obj,subjectstring,makeit)
			% DOES_SUBJECTSTRING_MATCH_SESSION_DOCUMENT - does a subject string match a document?
			%
			% [B, SUBJECT_ID] = DOES_SUBJECTSTRING_MATCH_SESSION_DOCUMENT(NDI_SESSION_OBJ, ...
			%    SUBJECTSTRING, MAKEIT)
			%
			% Given a SUBJECTSTRING, which is either the local identifier for a subject in the
			% NDI_SESSION object, or a document ID in the database, determine if the SUBJECTSTRING
			% corresponds to an NDI_DOCUMENT already in the database. If so, then the ID of that document
			% is returned in SUBJECT_ID and B is 1. If it is not there, and if MAKEIT is 1, then
			% a new entry is made and the document id is returned in SUBJECT_ID. If MAKEIT is 0, and it is
			% not there, then B is 0 and SUBJECT_ID is empty.
			%
				need_to_make_it = 0;
				b = 0;
				subject_id = '';

				islocal = ndi_subject.isvalidlocalidentifierstring(subjectstring);
				if islocal,
					subject_doc = ndi_session_obj.database_search(...
						ndi_query('subject.local_identifier','exact_string',subjectstring,''));
				else,
					subject_doc = ndi_session_obj.database_search(...
						ndi_query('ndi_document.id','exact_string',subjectstring,''));
				end;
				if numel(subject_doc)==1,
					subject_id = subject_doc{1}.document_properties.ndi_document.id;
					b = 1;
					return;
				elseif numel(subject_doc)==0,
					if islocal&makeit,
						newsubject = ndi_subject(subjectstring,'');
						subject_doc = newsubject.newdocument();
						ndi_session_obj.database_add(subject_doc);
						subject_id = subject_doc.document_properties.ndi_document.id;
						b = 1;
					else,
						return;
					end;
				elseif numel(subject_doc)>1,
					error(['More than one subject doc matches..should only be 1!']);
				end;
		end; % does_subjectstring_match_session_document()
	end; % static methods
end % classdef ndi_subject


