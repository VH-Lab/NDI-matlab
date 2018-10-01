classdef nsd_variable < nsd_dbleaf_branch
	% NSD_VARIABLE - A variable class for NSD
	%
	% NSD_VARIABLE
	%
	% NSD_VARIABLEs allow the systematic storage of named variables
	% with paticular values. They can be accessed from an NSD_EXPERIMENT
	% object.
	%
	% See also: NSD_VARIABLE/NSD_VARIABLE, NSD_VARIABLE_BRANCH, NSD_VARIABLE_BRANCH/NSD_VARIABLE_BRANCH
	%
	% Examples:
	%	% if exp is an NSD_EXPERIMENT object
	%		% BRANCHES a.k.a. subdirectories
	%	myvardir = nsd_variable_branch(exp.variable,'Animal parameters');
	%		% or
	%	myvardir = exp.variable.load_createbranch('Animal parameters'); % loads it if it is already there, creates it otherwise
	%
	%		% DOUBLE ARRAYS
	%	myvar = nsd_variable(myvardir, 'Animal age','double','Animal age in days', ...
	%		30, 'The age of the animal at the time of the experiment (days)','');
 	%
	%		% FILES
	%	myfilevar = nsd_variable(myvardir, 'Things to write','file', 'Test: Some things to write', ...
	%		[], 'Some things to write','no history');
	% 		% store some data in the file
	%		fname = myfilevar.filename();
	%		fid = fopen(fname,'w','b'); % write big-endian
	%		fwrite(fid,char([0:9]));
	%		fclose(fid);
	%
	%		% STRUCTURES
	%	mystruct.a = 5;
	%	mystruct.b = 3;
	%	mystructvar = nsd_variable(myvardir, 'Structure to write', 'struct', 'Test: A test structure', ...
	%		mystruct, 'Some things to write', 'no history');
	% 

	properties (GetAccess=public,SetAccess=protected)
		dataclass    % A string describing the class of the data ('double', 'char', or 'bin')
		type         % formal type name
		data         % Data to be stored
		description  % A human-readable description of the variable's purpose
		history      % A character string description of the variable's history (what created it, etc)
	end

	methods
		function obj = nsd_variable(parent, name, dataclass, type, data, description, history)
			% NSD_VARIABLE - Create an NSD_VARIABLE object
			%
			%  OBJ = NSD_VARIABLE(PARENT, NAME, DATACLASS, TYPE, DATA, DESCRIPTION, HISTORY)
			%
			%  Creates a variable to be linked to an experiment:
			%  PARENT      - must be an NSD_DBLEAF_BRANCH object (or descendendant class, such as
			%                  NSD_VARIABLE_BRANCH), usually the variable list associated with an NSD_EXPERIMENT
			%                  or its children.
			%  NAME        - the name for the variable; may be any string
			%  DATACLASS   - a string describing the data; it may be 'double', 'char', or 'bin', 'file', or 'struct'
			%  TYPE        - a string describing the type of data stored, for other programs to read	
			%                  (e.g., 'Spike times')
			%  DATA        - the data to be stored
			%  DESCRIPTION - a human-readable string description of the variable's contents and purpose
			%  HISTORY     - a character string description of the variable's history (what function created it,
			%                 parameters, etc)

			loadfilename = '';

			isflat = 1;
			classnames = {};

			if nargin==0 | nargin==2, % undocumented 0 argument creator or loadcommand
				if nargin==2,
					loadfilename= parent;
				end;
				parent = [];
				isinmemory = 0;
				name='';
				dataclass='double';
				type = '';
				data=[];
				description='';
				history='';
			end

			if ~isempty(parent)&~isa(parent,'nsd_dbleaf_branch'),
				error(['NSD_VARIABLE_FILE objects must be attached to NSD_DBLEAF_BRANCH objects or descendant classes.']);
			elseif ~isempty(parent),
				isinmemory = parent.memory;
			end

			if ~ischar(description),
				error(['description must be a character string (it can be the empty string '''') .']);
			end;

			if ~ischar(history)
				error(['history must be a character string (it can be the empty string '''') .']);
			end;

			obj = obj@nsd_dbleaf_branch(parent, name, classnames, isflat, isinmemory,0);
			if ~obj.allowedclass(dataclass),
				error(['class must be ''double'', ''char'', ''bin'', ''file'', or ''struct''']);
			end
			obj.dataclass=dataclass;
			obj.data=data;
			obj.type = type;
			obj.description=description;
			obj.history=history;
			if ~isempty(parent),
				parent.addreplace(obj);
			end;
			if ~isempty(loadfilename),
				obj = obj.readobjectfile(loadfilename);
			end;
		end % nsd_variable creator

		function b = allowedclass(nsd_variable_obj, dataclass)
			% ALLOWEDCLASS - is this dataclass allowed as a variable?
			%
			% B = ALLOWEDCLASS(NSD_VARIABLE_OBJ, DATACLASS)
			%
			% Returns 1 if DATACLASS is an allowed type. Returns 0 otherwise.
			%
			% For NSD_VARIABLE objects: 'char', 'double', or 'bin' are allowed.
			%
				b = 0;

				switch(lower(dataclass)),
					case {'double','char','bin','file','struct'},
						b = 1;
				end
		end % allowedclass

		function [data,fieldnames] = stringdatatosave(nsd_variable_obj)
			% STRINGDATATOSAVE - Returns a set of strings to write to file to save object information
			%
			% [DATA,FIELDNAMES] = STRINGDATATOSAVE(NSD_VARIABLE_OBJ)
			%
			% Return a cell array of strings to save to the objectfilename
			%
			% For NSD_VARIABLE, this returns all of the NSD_DBLEAF items, plus
			% the values of properties dataclass, description, and history.
			%
			% FIELDNAMES is a set of names of the fields/properties of the object
			% that are being stored.
			%
				[data,fieldnames] = stringdatatosave@nsd_dbleaf_branch(nsd_variable_obj);
				data{end+1} = nsd_variable_obj.dataclass;
				fieldnames{end+1} = 'dataclass';
				data{end+1} = nsd_variable_obj.type;
				fieldnames{end+1} = 'type';
				data{end+1} = nsd_variable_obj.description;
				fieldnames{end+1} = 'description';
				data{end+1} = nsd_variable_obj.history;
				fieldnames{end+1} = 'history';
		end % stringdatatosave

		function [obj,properties_set] = setproperties(nsd_variable_obj, properties, values)
			% SETPROPERTIES - set the properties of an NSD_VARIABLE object
			%
			% [OBJ,PROPERTIESSET] = SETPROPERTIES(NSD_VARIABLE_OBJ, PROPERTIES, VALUES)
			%
			% Given a cell array of string PROPERTIES and a cell array of the corresponding
			% VALUES, sets the fields in NSD_VARIABLE_OBJ and returns the result in OBJ.
			%
			% If any entries in PROPERTIES are not properties of NSD_VARIABLE_OBJ, then
			% that property is skipped.
			%
			% The properties that are actually set are returned in PROPERTIESSET.
			%
			% Developer note: when creating a subclass of NSD_DBLEAF that has its own properties that
			% need to be read/written from disk, copy this method SETPROPERTIES into the new class so that
			% you will be able to set all properties (this instance can only set properties of NSD_DBLEAF).
			%
				fn = fieldnames(nsd_variable_obj);
				obj = nsd_variable_obj;
				properties_set = {};
				for i=1:numel(properties),
					if any(strcmp(properties{i},fn)) | any (strcmp(properties{i}(2:end),fn)),
						if properties{i}(1)~='$',
							eval(['obj.' properties{i} '= values{i};']);
							properties_set{end+1} = properties{i};
						else,
							eval(['obj.' properties{i}(2:end) '=' values{i} ';']);
							properties_set{end+1} = properties{i}(2:end);
						end
					end
				end
			end % setproperties

		function nsd_variable_obj = updatedata(nsd_variable_obj, newdata)
			% UPDATE_DATA - Update the data field of an NSD_VARIABLE object
			%
			% NSD_VARIABLE_OBJ = UPDATE_DATA(NSD_VARIABLE_OBJ, NEWDATA)
			%
			% Update the data field of an NSD_VARIABLE object, including on disk.
			%
				nsd_variable_obj.data = newdata;
				nsd_variable_obj.writeobjectdata;
		end % update_data

		function fname = filename(nsd_variable_obj)
			% FILENAME - return the name of the file that is written to store the variable data
			%
			% FNAME = FILENAME(NSD_VARIABLE_FILE)
			%
			% Returns the full path filename FNAME of a file that is used to store data.
			% 
			% Don't touch this file unless you are using dataclass 'file'.
			%
				d = dirname(nsd_variable_obj);
				if isempty(d),
					error(['There is no file path associated with this object; object may be in memory only.']);
				else,
					fname = [d filesep nsd_variable_obj.objectfilename '.datafile.nsd_variable.nsd'];
				end
			end % filename

		function nsd_variable_obj=writeobjectdata(nsd_variable_obj, locked)
			% WRITEOBJECTDATA - write the actual data for the object to the object's data file
			%
			% WRITEOBJECTDATA(NSD_VARIABLEOBJ)
			%
			% Writes the data to the data file.
			%
				if nargin<2,
					locked = 0;
				end

				thisfunctionlocked = 0;
				d = [];

				if ~locked,
					d = dirname(nsd_variable_obj);
					nsd_variable_obj = nsd_variable_obj.lock(d);
					thisfunctionlocked = 1;
					locked = 1;
				end
				
				fname = nsd_variable_obj.filename;

				fid = fopen(fname,'w','b');     % files will consistently use big-endian
				if fid < 0,
					error(['Could not open the file ' fname ' for writing.']);
				end;

				if ~isempty(nsd_variable_obj.dataclass),
					switch nsd_variable_obj.dataclass,
						case 'file', % do nothing
							fclose(fid);
						case 'struct',
							fclose(fid);
							saveStructArray(nsd_variable_obj.filename,nsd_variable_obj.data, 1);
						otherwise,
							writeplainmat(fid, nsd_variable_obj.data);
							fclose(fid);
					end
				end

				if thisfunctionlocked, % we locked it, we need to unlock it
					nsd_variable_obj = nsd_variable_obj.unlock(d);
				end
			end

		function nsd_variable_obj=writeobjectfile(nsd_variable_obj, dirname, locked)
			% WRITEOBJECTFILE - write the object file to a file
			%
			% WRITEOBJECTFILE(NSD_VARIABLEOBJ, DIRNAME, [LOCKED])
			%
			% Writes the NSD_VARIABLEOBJ to a file in a manner that can be
			% read by the creator function NSD_BASE.
			%
			% Writes to the path DIRNAME/NSD_VARIABLE_OBJ.OBJECTFILENAME
			%
			% If LOCKED is 1, then the calling function has verified a correct
			% lock on the file and WRITEOBJECTFILE shouldn't lock/unlock it.
			%
				if nargin<3,
					locked = 0;
				end

				thisfunctionlocked = 0;
				if ~locked, % we need to lock it
					nsd_variable_obj = nsd_variable_obj.lock(dirname);
					thisfunctionlocked = 1;
					locked = 1;
				end

				writeobjectfile@nsd_dbleaf_branch(nsd_variable_obj, dirname, locked);

				nsd_variable_obj.writeobjectdata(locked);

				if thisfunctionlocked,  % we locked it, we need to unlock it
					nsd_variable_obj = nsd_variable_obj.unlock(dirname);
				end
		end % writeobjectfile()

		function nsd_variable_obj = readobjectfile(nsd_variable_obj, filename)
			% READOBJECTFILE - read the object from a file
			%
			% OBJ = READOBJECTFILE(NSD_VARIABLE_OBJ, FILENAME)
			%
			% Reads the NSD_VARIABLE_OBJ from the file FILENAME.
			%
			% The file format consists of several strings that are read in sequence.
			% The first line is always the name of the object class.
			%
				nsd_variable_obj= readobjectfile@nsd_dbleaf_branch(nsd_variable_obj, filename); 

				fid = fopen(nsd_variable_obj.filename,'r','b');
				if fid<0,
					error(['Could not open file ' filename ' for reading.']);
				end

				switch nsd_variable_obj.dataclass,
					case 'file',
						% do nothing
					case 'struct',
						nsd_variable_obj.data = loadStructArray(nsd_variable_obj.filename);
					otherwise,
						nsd_variable_obj.data = readplainmat(fid);
				end

				fclose(fid);
                end % readobjectfile()

		function mds = metadatastruct(nsd_variable_obj)
			% METADATASTRUCT - return the metadata fields and values for an NSD_VARIABLE object
			%
			% MDS = METADATASTRUCT(NSD_VARIABLE_OBJ)
			%
			% Returns the metadata fieldnames and values for NSD_VARIABLE_OBJ. This adds the properties
			% 'dataclass', 'type', 'description', and 'history'.
			%
				mds = metadatastruct@nsd_dbleaf_branch(nsd_variable_obj);
				mds.dataclass = nsd_variable_obj.dataclass;
				mds.type= nsd_variable_obj.type;
				mds.description = nsd_variable_obj.description;
				mds.history = nsd_variable_obj.history;
		end % metadatastruct()
	end % methods
end % classdef

