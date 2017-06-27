classdef nsd_base < handle
	% NSD_BASE - A node that fits into an NSD_BASE_BRANCH
	%
	%

	properties (GetAccess=public,SetAccess=protected)
		objectfilename % Unique name that can be used to store the item in a file on disk
	end % properties
	properties (GetAccess=protected, SetAccess=protected)
		lockfid        % File ID of the lockfile, if it is created
	end

	methods
		function obj = nsd_base(filename, command)
			% NSD_BASE - Creates a named NSD_BASE object
			%
			% OBJ = NSD_BASE
			%
			% Creates an NSD_BASE object. Each NSD_BASE object has a unique
			% identifier that is stored in the property 'objectfilename'. The class
			% includes methods for writing and reading object files in a platform- and
			% language-independent manner.
			%
			% In an alternate construction, one may call
			%
			%   OBJ = NSD_BASE(FILENAME, COMMAND)
			% with COMMAND set to 'OpenFile', and the object will be created by
			% reading in data from the file FILENAME (full path). To developers:
			% All NSD_BASE descendents must offer this 2 element constructor.
			%  
			% See also: NSD_DBLEAF, NSD_BASE

			obj.objectfilename = ['object_' num2hex(now) '_' num2hex(rand) '' ]; 
			obj.lockfid = [];

			if nargin<2,
				command = '';
			end

			if strcmp(lower(command),lower('OpenFile')),
				obj = obj.readobjectfile(filename);
			end

		end % nsd_base

		function obj = readobjectfile(nsd_base_obj, filename)
			% READOBJECTFILE - read the object from a file
			%
			% OBJ = READOBJECTFILE(NSD_BASE_OBJ, FILENAME)
			%
			% Reads the NSD_BASE_OBJ from the file FILENAME.
			%
			% The file format consists of several strings that are read in sequence.
			% The first line is always the name of the object class.
			%
				fid = fopen(filename, 'rb'); % files will consistently use big-endian
				if fid<0,
					error(['Could not open the file ' filename ' for reading.']);
				end;
				
				classname = fgetl(fid);

				if strcmp(classname,class(nsd_base_obj)),
					% we have the right type of object
					[dummy,fn] = nsd_base_obj.stringdatatosave();
					values = {};
					obj = nsd_base_obj;
					for i=2:length(fn),
						values{i} = fgetl(fid);
					end;
					obj = setproperties(obj, fn, values);
					fclose(fid);
				else,
					fclose(fid);
					error(['Not a valid NSD_BASE file:' filename ]);
				end;

		end % readobjectfile

		function b = deleteobjectfile(nsd_base_obj, dirname)
			% DELETEOBJECTFILE - Delete / remove the object file (or files) for NSD_BASE
			%
			% B = DELETEOBJECTFILE(NSD_BASE_OBJ, DIRNAME)
			%
			% Delete all files associated with NSD_BASE_OBJ in directory DIRNAME (full path).
			%
			% B is 1 if the process succeeds, 0 otherwise.
			%
				filename = [dirname filesep nsd_base_obj.objectfilename];
				b = 1;
				try,
					delete(filename);
				catch,
					b = 0;
				end
		end

		function [obj,properties_set] = setproperties(nsd_base_obj, properties, values)
			% SETPROPERTIES - set the properties of an NSD_BASE object
			%
			% [OBJ,PROPERTIESSET] = SETPROPERTIES(NSD_BASE_OBJ, PROPERTIES, VALUES)
			%
			% Given a cell array of string PROPERTIES and a cell array of the corresponding
			% VALUES, sets the fields in NSD_BASE_OBJ and returns the result in OBJ.
			%
			% If any entries in PROPERTIES are not properties of NSD_BASE_OBJ, then 
			% that property is skipped.
			%
			% The properties that are actually set are returned in PROPERTIESSET.
			%
			% Developer note: when creating a subclass of NSD_BASE that has its own properties that
			% need to be read/written from disk, copy this method SETPROPERTIES into the new class so that
			% you will be able to set all properties (this instance can only set properties of NSD_BASE).
			%
				fn = fieldnames(nsd_base_obj);
				obj = nsd_base_obj;
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
			end
			
		function nsd_base_obj=writeobjectfile(nsd_base_obj, dirname, locked)
			% WRITEOBJECTFILE - write the object file to a file
			% 
			% WRITEOBJECTFILE(NSD_BASE_OBJ, DIRNAME, [LOCKED])
			%
			% Writes the NSD_BASE_OBJ to a file in a manner that can be
			% read by the creator function NSD_BASE.
			%
			% Writes to the path DIRNAME/NSD_BASE_OBJ.OBJECTFILENAME
			%
			% If LOCKED is 1, then the calling function has verified a correct
			% lock on the file and WRITEOBJECTFILE shouldn't lock/unlock it.
			%
			% See also: NSD_BASE/NSD_BASE
			%

				if nargin<3,
					locked = 0;
				end;

				thisfunctionlocked = 0;
				if ~locked, % we need to lock it
					nsd_base_obj = nsd_base_obj.lock(dirname)
					thisfunctionlocked = 1;
				end

				filename = [dirname filesep nsd_base_obj.objectfilename];
				fid = fopen(filename,'wb');	% files will consistently use big-endian
				if fid < 0,
					error(['Could not open the file ' filename ' for writing.']);
				end;

				data = nsd_base_obj.stringdatatosave();

				for i=1:length(data),
					count = fprintf(fid,'%s\n',data{i});
					if count~=numel(data{i})+1,
						error(['Error writing to the file ' filename '.']);
					end
				end

				fclose(fid);

				if thisfunctionlocked,
					nsd_base_obj = nsd_base_obj.unlock(dirname);
				end

		end % writeobjectfile

		function [data, fieldnames] = stringdatatosave(nsd_base_obj)
			% STRINGDATATOSAVE - Returns a set of strings to write to file to save object information
			%
			% [DATA,FIELDNAMES] = STRINGDATATOSAVE(NSD_BASE_OBJ)
			%
			% Return a cell array of strings to save to the objectfilename.
			%
			% FIELDNAMES is a set of names of the fields/properties of the object
			% that are being stored.
			%
			% For NSD_BASE, this returns the classname, name, and the objectfilename.
			%
			% Developer note: If you create a subclass of NSD_BASE with properties, it is recommended
			% that you implement your own version of this method. If you have only properties that can be stored
			% efficiently as strings, then you will not need to include a WRITEOBJECTFILE method.
			%
				data = {class(nsd_base_obj) nsd_base_obj.objectfilename};
				fieldnames = { '', 'objectfilename' };

		end % stringdatatosave

                function lockfname = lockfilename(nsd_base_obj, dirname)
                        % LOCKFILENAME - the filename of the lock file that serves as a semaphore to maintain data integrity
                        %
                        % LOCKFNAME = LOCKFILENAME(NSD_BASE_OBJ, DIRNAME)
                        %
                        % Returns the filename that is used for locking the metadata and object data files.
			%
			% DIRNAME is the directory to use (full path).
                        %
                        % See also: NSD_BASE/LOCK NSD_BASE/UNLOCK NSD_BASE/LOCKFILENAME

				filename = [dirname filesep nsd_base_obj.objectfilename];
                                lockfname = [filename '-lock'];

                end % lockfilename()

                function [nsd_base_obj, b] = lock(nsd_base_obj, dirname)
			% LOCK - lock the metadata file and object files so other processes cannot change them
			%
			% [NSD_BASEOBJ, B] = LOCK(NSD_BASEOBJ, DIRNAME)
			%
			% Attempts to obtain the lock on the object file. If it is successful,
			% B is 1. Otherwise, B is 0. DIRNAME is the directory where the file(s)
			% is(are) stored (full path).
			%
			% Note: Only a function that calls LOCK should call UNLOCK to maintain integrety of object data.
			%
			% See also: NSD_BASE/LOCK NSD_BASE/UNLOCK NSD_BASE/LOCKFILENAME

				b = 0;

				lockfid = checkout_lock_file(nsd_base_obj.lockfilename(dirname));
				if lockfid>0,
					nsd_base_obj.lockfid = lockfid;
					b = 1;
				end

                end % lock()

                function [nsd_base_obj, b] = unlock(nsd_base_obj, dirname)
			% UNLOCK - unlock the metadata file and object files so other processes can change them
			%
			% [NSD_BASE_OBJ, B] = UNLOCK(NSD_BASE_OBJ, DIRNAME)
			%
			% Removes the lock file from the NSD_BASE NSD_BASE_OBJ.
			%
			% DIRNAME is the directory where the file(s) is (are) stored (full path).
			%
			% Note: Only a function that calls LOCK should call UNLOCK to maintain integrety of metadata and object data.
			% The function returns B=1 if the operation was successful, B=0 otherwise.
			%
			% See also: NSD_BASE/LOCK NSD_BASE/UNLOCK NSD_BASE/LOCKFILENAME

				b = 1;
				if ~isempty(nsd_base_obj.lockfid),
					try,
						fclose(nsd_base_obj.lockfid);
						delete(nsd_base_obj.lockfilename(dirname));
						nsd_base_obj.lockfid = [];
					catch,
						b = 0;
					end;
				end;

                end % unlock()

	end % methods 

end
