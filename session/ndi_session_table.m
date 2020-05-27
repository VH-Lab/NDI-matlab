classdef ndi_session_table 
% NDI_SESSION_TABLE - a table for managing the file paths of NDI sessions
%
%

	properties
		

	end; 

	methods 

		function thepath = getsessionpath(ndi_session_table_obj, session_id)
			% GETSESSIONPATH - look up the path of an NDI_SESSION by its ID
			%
			% THEPATH = GETSESIONPATH(SESSION_ID)
			%
			% Examines the NDI_SESSION_TABLE object to see if a path is known for a session
			% with an ID of SESSION_ID. Otherwise, empty ([]) is returned;
			%
				thepath = [];
				t = ndi_session_table_obj.getsessiontable();
				i = find(strcmp(session_id,{t.session_id}));
				if ~isempty(i),
					thepath = t(i(1)).path; % pick first match, should be only match
				end;
		end; % getsessionpath()

		function t = getsessiontable(ndi_session_table_obj)
			% GETSESSIONTABLE - return the session table 
			%
			% T = GETSESSIONTABLE(NDI_SESSION_TABLE_OBJ)
			%
			% Returns the session table, a structure with fields 'SESSION_ID' and 'PATH'. Each entry
			% in the table corresponds to a recently-opened or added path of NDI_SESSION_DIR. 
			%
				t = emptystruct('session_id','path');
				fname = ndi_session_table.localtablefilename();
				if exist(fname,'file'),
					try,
						t = loadStructArray(fname);
						if ~isfield(t,'path'),
							error(['path is a required field.']);
						end;
						if ~isfield(t,'session_id'),
							error(['session_id is a required field.']);
						end;
					catch,
						warning(['Local session table file ' fname ' appears corrupted, ignoring.']);
					end;
				end;
		end; % getsessiontable()

		function addtableentry(ndi_session_table_obj, session_id, path);
			% ADDTABLEENTRY - add an entry to an NDI_SESSION_TABLE
			%
			% ADDTABLEENTRY(NDI_SESSION_TABLE_OBJ, SESSION_ID, PATH)
			% 
			% Adds SESSION_ID and PATH as an entry to the session table.
			% If SESSION_ID is already in the table, then the entry is replaced.
			%
				if ~ischar(session_id),
					error(['Session_id must be a character array.']);
				end;
				if ~ischar(path),
					error(['PATH must be a character array.']);
				end;
				ndi_session_table_obj.removetableentry(session_id);
				t = ndi_session_table_obj.getsessiontable();
				t(end+1) = struct('session_id',session_id,'path',path);
				ndi_session_table_obj.writetable(t);

		end; % addtableentry()

		function removetableentry(ndi_session_table_obj, session_id)
			% REMOVETABLEENTRY - remove an entry of an NDI_SESSION_TABLE
			%
			% REMOVETABLEENTRY(NDI_SESSION_TABLE_OBJ, SESSION_ID)
			%
			% Removes the entry of an NDI_SESSION_TABLE with the given SESSION_ID.
			%
			%
				t = ndi_session_table_obj.getsessiontable();
				i = find(strcmp(session_id,{t.session_id}));
				if ~isempty(i), % only act if we need to
					t = t(setdiff(1:numel(t),i)); 
					ndi_session_table_obj.writetable(t);
				end;

		end; % removetableentry()


		function [b,results] = checktable(ndi_session_table_obj)
			%CHECKTABLE - check the session table for proper form, accessibility
			%
			% [B, RESULTS] = CHECKTABLE(NDI_SESSION_TABLE_OBJ)
			%
			% Check the NDI_SESSION_TABLE object's session table to see if it has the right
			% form (B is 1 if it does, B is 0 otherwise). (It has the right form if it is a structure with fieldnames
			% 'path' and 'sesion_id'.
			%
			% If the table has the right form RESULTS is a structure array with one entry per entry in the table.
			% It has a field 'exists' which is 1 if the path currently exists on the user's machine. If the table does not
			% have the right form, then RESULTS is empty.
			%
				b = 0;
				results = emptystruct('exists');
				t = ndi_session_table_obj.getsessiontable();
				[b,msg] = ndi_session_table_obj.isvalidtable(t);
				if b,
					for i=1:numel(t),
						resultshere.exists = exist(t(i).path,'dir');
						results(i) = resultshere;
					end;
				end;
				
		end; % checktable()

		function [b,msg] = isvalidtable(ndi_session_table_obj, t)
			% ISVALIDTABLE - Does the session table have the correct fields?
			%
			% [B,MSG] = ISVALIDTABLE(NDI_SESSION_TABLE_OBJ, [T])
			%
			% B is 1 if the NDI SESSION TABLE is a structure array with fields
			% 'path' and 'session_id', all text fields. B is 0 otherwise. If T
			% is not provided, then the session table is read.
			%
			% If B is 0, then an error description is provided in MSG. MSG is '' otherwise.
			%
				b = 1;
				msg = '';

				if nargin<2,
					t = ndi_session_table_obj.getsessiontable();
				end;
				if ~isfield(t,'path'),
					b = 0;
					msg = ['path is a required field.'];
					return;
				end;
				if ~isfield(t,'session_id'),
					b = 0;
					msg = ['session_id is a required field.'];
					return;
				end;
				for i=1:numel(t),
					if ~ischar(t(i).path),
						b = 0;
						msg = ['Entry ' int2str(i) ' of session table path is not a character array.'];
						return;
					end;
					if ~ischar(t(i).session_id),
						b = 0;
						msg = ['Entry ' int2str(i) ' of session table session_id is not a character array.'];
						return;
					end;
				end;
		end; % isvalidtable() 

	end; % methods

	methods (Access=protected)
		function writetable(ndi_session_table_obj, t)
			% WRITETABLE - write the session table to disk
			%
			% WRITETABLE(NDI_SESSION_TABLE_OBJ, T)
			%
			% Save the table T to disk as the session table.
			% The table is first checked for validity.
			% An error is triggered if the table is invalid or cannot be written.
			%
				[b,msg] = ndi_session_table_obj.isvalidtable(t);
				if ~b,
					error(['Session table not valid: ' msg ]);
				end;
				fname = ndi_session_table.localtablefilename();
				lockfilename = [fname '-lockfile'];
				lockfid = checkout_lock_file(lockfilename);
				if lockfid > 0,
					saveStructArray(fname,t);
					fclose(lockfid);
					delete(lockfilename);
				else
					error(['Could not check out lock file to gain exclusive write access; ' ...
						'delete file if you think it exists in error: ' lockfilename]);
				end;
		end; % writetable()

	end % methods (Protected)

	methods (Static)

		function f = localtablefilename()
			% LOCALTABLEFILENAME - return the session table filename
			%
			% F = LOCALTABLEFILENAME()
			%
				ndi_globals;
				f = [ndi.path.preferences filesep 'local_session_table.txt'];
		end; % tablefilename()

	end; % static methods

end % class
