classdef nsd_variable < nsd_dbleaf
	% NSD_VARIABLE - A variable class for NSD
	%
	% NSD_VARIABLE
	%
	% NSD_VARIABLEs allow the systematic storage of named variables
	% with paticular values. They can be accessed from an NSD_EXPERIMENT
	% object.
	%

	properties (GetAccess=public,SetAccess=protected)
		dataclass    % A string describing the class of the data ('double', 'char', or 'bin')
		data         % Data to be stored
		description  % A human-readable description of the variable's purpose
		history      % A character string description of the variable's history (what created it, etc)
	end

	methods
		function obj = nsd_variable(name, dataclass, data, description, history)
			% NSD_VARIABLE - Create an NSD_VARIABLE object
			%
			%  OBJ = NSD_VARIABLE(NAME, DATACLASS, DATA, DESCRIPTION, HISTORY)
			%
			%  Creates a variable to be linked to an experiment:
			%  NAME        - the name for the variable; may be any string
			%  DATACLASS   - a string describing the data; it may be 'double', 'char', or 'bin'
			%  DATA        - the data to be stored
			%  DESCRIPTION - a human-readable string description of the variable's contents and purpose
			%  HISTORY     - a character string description of the variable's history (what function created it,
			%                 parameters, etc)

			loadfilename = '';

			if nargin==0 | nargin==2, % undocumented 0 argument creator or loadcommand
				if nargin==2, loadfilename= name; end;
				name='';
				dataclass='double';
				data=[];
				description='';
				history='';
			end

			switch lower(dataclass),
				case {'double','char','bin'},
					% do nothing
				otherwise,
					error(['class must be ''double'', ''char'', or ''bin''']);
			end

			if ~ischar(description),
				error(['description must be a character string (it can be the empty string '''') .']);
			end;

			if ~ischar(history)
				error(['history must be a character string (it can be the empty string '''') .']);
			end;

			obj = obj@nsd_dbleaf(name);
			obj.dataclass=dataclass;
			obj.data=data;
			obj.description=description;
			obj.history=history;
			if ~isempty(loadfilename),
				obj = obj.readobjectfile(loadfilename);
			end;

		end % nsd_variable

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
				[data,fieldnames] = stringdatatosave@nsd_dbleaf(nsd_variable_obj);
				data{end+1} = nsd_variable_obj.dataclass;
				fieldnames{end+1} = 'dataclass';
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


		function nsd_variableobj=writeobjectfile(nsd_variable_obj, dirname, locked)
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

				writeobjectfile@nsd_dbleaf(nsd_variable_obj, dirname, locked);

				filename = [dirname filesep nsd_variable_obj.objectfilename];
				fid = fopen(filename,'ab');     % files will consistently use big-endian
				if fid < 0,
					error(['Could not open the file ' filename ' for writing.']);
                                end;

				sz = size(nsd_variable_obj.data);
				count=fwrite(fid,numel(sz),'double'); % now have written the size of the size vector
				if count~=1,
					error(['size of data written does not match request.']);
				end
				count=fwrite(fid,uint32(sz(:)),'uint32'); % now have written the size of the vector to be stored
				if count~=numel(sz),
					error(['size of data written does not match request.']);
				end
				switch nsd_variable_obj.dataclass,
					case 'double',
						sizestr = 'double';
					case 'char',
						sizestr = 'char';
					case 'bin',
						sizestr = 'char';
					otherwise,
						error(['Unknown dataclass ' nas_variable_obj.dataclass '.']);
				end % switch

				count=fwrite(fid, nsd_variable_obj.data(:), sizestr);    % now have written the data

				if count~=prod(sz),
					error(['size of data written does not match request.']);
				end

				fclose(fid);

				if thisfunctionlocked,  % we locked it, we need to unlock it
					nsd_variable_obj = nsd_variable_obj.unlock(dirname);
				end

                end % writeobjectfile

                function obj = readobjectfile(nsd_variable_obj, filename)
                        % READOBJECTFILE - read the object from a file
                        %
                        % OBJ = READOBJECTFILE(NSD_VARIABLE_OBJ, FILENAME)
                        %
                        % Reads the NSD_VARIABLE_OBJ from the file FILENAME.
                        %
                        % The file format consists of several strings that are read in sequence.
                        % The first line is always the name of the object class.
                        %
				
				obj = readobjectfile@nsd_dbleaf(nsd_variable_obj, filename); 
				[data,fn] = stringdatatosave(obj);
				fid = fopen(filename,'rb');
				for i=1:numel(fn), fgetl(fid); end;  % read in that many lines to skip the top of the file

				switch obj.dataclass,
					case 'double',
						sizestr = 'double';
					case 'char','bin',
						sizestr = 'char';
					otherwise,
						error(['Unknown dataclass.']);
				end

				n = fread(fid,1,'double'); % read in the size of size
				sz = fread(fid,n,'uint32'); % read in the size
				data = fread(fid,prod(sz),sizestr);
				fclose(fid);
				obj.data = reshape(data,sz(:)');

                end % readobjectfile

	end % methods
end % classdef

