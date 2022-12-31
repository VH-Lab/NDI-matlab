% NDI_SESSION_DIR - NDI_SESSION_DIR object class - an session with an associated file directory
%

classdef dir < ndi.session
	properties (GetAccess=public,SetAccess=protected)
		path    % the file path of the session
	end

	methods
		function ndi_session_dir_obj = dir(reference, path)
			% ndi.session.dir - Create a new ndi.session.dir ndi_session_dir_object
			%
			%   E = ndi.session.dir(REFERENCE, PATHNAME)
			%
			% Creates an ndi.session.dir ndi_session_dir_object, or an session with an
			% associated directory. REFERENCE should be a unique reference for the
			% session and directory PATHNAME.
			%
			% One can also open an existing session by using
			%
			%  E = ndi.session.dir(PATHNAME)
			%
			% See also: ndi.session, ndi.session.dir/GETPATH

				if nargin==1,
					path = reference;
					ref = 'temp';
				end

				if ~exist(path,'dir'),
					error(['Directory ' path ' does not exist.']);
				end;

				ndi_session_dir_obj = ndi_session_dir_obj@ndi.session(reference);
				ndi_session_dir_obj.path = path;
				d = dir([ndi_session_dir_obj.ndipathname() filesep 'reference.txt']);
				if ~isempty(d),
					ndi_session_dir_obj.reference = strtrim(vlt.file.textfile2char(...
						[ndi_session_dir_obj.ndipathname() filesep 'reference.txt']));
				elseif nargin==1,
					error(['Could not load the REFERENCE field from the path ' ndi_session_dir_obj.ndipathname() '.']);
				end
				d = dir([ndi_session_dir_obj.ndipathname() filesep 'unique_reference.txt']);
				if ~isempty(d),
					ndi_session_dir_obj.identifier = strtrim(vlt.file.textfile2char(...
						[ndi_session_dir_obj.ndipathname() filesep 'unique_reference.txt']));
				else,
					ndi_session_dir_obj.identifier = ndi.ido.unique_id();
				end

				ndi_session_dir_obj.database = ndi.database.fun.opendatabase(ndi_session_dir_obj.ndipathname(), ndi_session_dir_obj.id());

				syncgraph_doc = ndi_session_dir_obj.database_search( ndi.query('','isa','ndi_document_syncgraph','') & ...
					ndi.query('ndi_document.session_id', 'exact_string', ndi_session_dir_obj.id(), ''));

				if isempty(syncgraph_doc),
					ndi_session_dir_obj.syncgraph = ndi.time.syncgraph(ndi_session_dir_obj);
				else,
					if numel(syncgraph_doc)~=1,
						error(['Too many syncgraph documents found. Confused. There should be only 1.']);
					end;
					ndi_session_dir_obj.syncgraph = ndi.database.fun.ndi_document2ndi_object(syncgraph_doc{1},ndi_session_dir_obj);
				end;

				vlt.file.str2text([ndi_session_dir_obj.ndipathname() filesep 'reference.txt'], ...
					ndi_session_dir_obj.reference);
				vlt.file.str2text([ndi_session_dir_obj.ndipathname() filesep 'unique_reference.txt'], ...
					ndi_session_dir_obj.id());

				st = ndi.session.sessiontable();
				st.addtableentry(ndi_session_dir_obj.id(), ndi_session_dir_obj.path);
		end;
		
		function p = getpath(ndi_session_dir_obj)
			% GETPATH - Return the path of the session
			%
			%   P = GETPATH(NDI_SESSION_DIR_OBJ)
			%
			% Returns the path of an ndi.session.dir object.
			%
			% The path is some sort of reference to the storage location of
			% the session. This might be a URL, or a file directory.
			%
				p = ndi_session_dir_obj.path;
                end;

		function p = ndipathname(ndi_session_dir_obj)
			% NDSPATHNAME - Return the path of the NDI files within the session
			%
			% P = NDIPATHNAME(NDI_SESSION_DIR_OBJ)
			%
			% Returns the pathname to the NDI files in the ndi.session.dir object.
			%
			% It is the ndi.session.dir object's path plus [filesep '.ndi' ]

				ndi_dir = '.ndi';
				p = [ndi_session_dir_obj.path filesep ndi_dir ];
				if ~exist(p,'dir'),
					mkdir(p);
				end;
		end; % ndipathname()

		function b = eq(ndi_session_dir_obj_a, ndi_session_dir_obj_b)
			% EQ - Are two ndi.session.dir objects equivalent?
			%
			% B = EQ(NDI_SESSION_DIR_OBJ_A, NDI_SESSION_DIR_OBJ_B)
			%
			% Returns 1 if the two ndi.session.dir objects have the same
			% path and reference fields. They do not have to be the same handles
			% (that is, have the same location in memory).
			%
				b = 0;
				if eq@ndi.session(ndi_session_dir_obj_a, ndi_session_dir_obj_b),
					b = strcmp(ndi_session_dir_obj_a.path,ndi_session_dir_obj_b.path);
				end;
		end; % eq()
	end; % methods

end % classdef

