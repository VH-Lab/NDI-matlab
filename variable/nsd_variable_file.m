classdef nsd_variable_file < nsd_dbleaf_branch
	% NSD_VARIABLE_FILE - A variable file and directory of files class for NSD
	%
	% NSD_VARIABLE_FILE
	%

	properties (GetAccess=public,SetAccess=protected)
		description  % A human-readable description of the variable's purpose
		history      % A character string description of the variable's history (what created it, etc)
	end

	methods
		function obj = nsd_variable_file(parent, name, description, history)
			% NSD_VARIABLE_FILE - Create an NSD_VARIABLE_FILE object
			%
			%  OBJ = NSD_VARIABLE_FILE(PARENT, NAME, DESCRIPTION, HISTORY)
			%
			% Creates a variable directory to be linked to an NSD_EXPERIMENT
			% VARIABLE tree.
			%
			% PARENT must be an NSD_DBLEAF_BRANCH object, usually the variable list
			% associated with an NSD_EXPERIMENT or its children. 
			%  NAME        - the name for the variable; may be any string
			%  DESCRIPTION - a human-readable string description of the variable's contents and purpose
			%  HISTORY     - a character string description of the variable's history (what function created it,
			%                 parameters, etc)
			%
			% NSD_VARIABLE_FILE differs from its parent class NSD_DBLEAF_BRANCH in that 
			%  a) no NSD_DBLEAF objects may be added to it
			%  b) it has methods FILENAME and DIRNAME that return a full path filename or
			%     full path directory name where the user my store files
			%

			loadfilename = '';

			isinmemory = 0;
			isflat = 1;
			classnames = {};

			if nargin==0 | nargin==2,
				if nargin==2, % it is a loadfilename
					loadfilename = parent;
				end; 
				parent='';
				name='';
				description = '';
				history = '';
			end

			if ~isempty(parent)&~isa(parent,'nsd_dbleaf_branch'),
				error(['NSD_VARIABLE_FILE objects must be attached to NSD_DBLEAF_BRANCH objects.']);
			end;

			% this adds to the parent, too
			obj = obj@nsd_dbleaf_branch(parent,name,classnames,isflat,isinmemory);
			obj.description = description;
			obj.history = history;
			if ~isempty(loadfilename),
				obj = obj.readobjectfile(loadfilename); 
			elseif ~isempty(parent),
				parent.update(obj);
			end;

		end % nsd_variable_file

		function mds = metadatastruct(nsd_variable_file_obj)
			% METADATASTRUCT - return the metadata fields and values for an NSD_VARIABLE object
			%
			% MDS = METADATASTRUCT(NSD_VARIABLE_FILE_OBJ)
			%
			% Returns the metadata fieldnames and values for NSD_VARIABLE_FILE_OBJ. This adds the properties
			% 'description' and 'history'.
			%
				mds = metadatastruct@nsd_dbleaf(nsd_variable_file_obj);
				mds.description = nsd_variable_file_obj.description;
				mds.history = nsd_variable_file_obj.history;
		end % metadatastruct()

		function fname = filename(nsd_variable_file_obj)
			% FILENAME - return the name of a file that can be written to by the user's program
			%
			% FNAME = FILENAME(NSD_VARIABLE_FILE_OBJ)
			%
			% Returns the full path filename FNAME of a file that can be used to store data.
			% 
			%
			 	d = dirname(nsd_variable_file_obj);
				if isempty(d),
					error(['There is no file path associated with this object; object may be in memory only.']);
				else,
					dname = [d filesep nsd_variable_file_obj.objectfilename '.datafile.nsd_variable_file.nsd'];
				end
		end % filename()
	end % methods
end % classdef


