classdef ndi_base 
	% NDI_BASE - A node that fits into an NDI_BASE_BRANCH
	%
	%

	properties (GetAccess=public,SetAccess=protected)
		objectfilename % Unique name that can be used to store the item in a file on disk
	end % properties
	properties (GetAccess=protected, SetAccess=protected)
		lockfid        % File ID of the lockfile, if it is created
	end

	methods
		function obj = ndi_base(filename, command)
			% NDI_BASE - Creates a named NDI_BASE object
			%
			% OBJ = NDI_BASE
			%
			% Creates an NDI_BASE object. Each NDI_BASE object has a unique
			% identifier that is stored in the property 'objectfilename'. The class
			% includes methods for writing and reading object files in a platform- and
			% language-independent manner.
			%
			% In an alternate construction, one may call
			%
			%   OBJ = NDI_BASE(FILENAME, COMMAND)
			% with COMMAND set to 'OpenFile', and the object will be created by
			% reading in data from the file FILENAME (full path). To developers:
			% All NDI_BASE descendents must offer this 2 element constructor.
			%  
			% See also: NDI_DBLEAF, NDI_BASE

			obj.objectfilename = ['object_' ndi_unique_id() ];
			obj.lockfid = [];

			if nargin<2,
				command = '';
			end

			if strcmp(lower(command),lower('OpenFile')),
				obj = obj.readobjectfile(filename);
			end

		end % ndi_base

		function obj = readobjectfile(ndi_base_obj, filename)
			% READOBJECTFILE - read the object from a file
			%
			% OBJ = READOBJECTFILE(NDI_BASE_OBJ, FILENAME)
			%
			% Reads the NDI_BASE_OBJ from the file FILENAME.
			%
			% The file format consists of several strings that are read in sequence.
			% The first line is always the name of the object class.
			%
				fid = fopen(filename, 'rb'); % files will consistently use big-endian
				if fid<0,
					error(['Could not open the file ' filename ' for reading.']);
				end;
				
				classname = fgetl(fid);

				if strcmp(classname,class(ndi_base_obj)),
					% we have the right type of object
					[dummy,fn] = ndi_base_obj.stringdatatosave();
					values = {};
					obj = ndi_base_obj;
					for i=2:length(fn),
						values{i} = fgetl(fid);
					end;
					obj = setproperties(obj, fn, values);
					fclose(fid);
				else,
					fclose(fid);
					error(['Not a valid NDI_BASE file:' filename ]);
				end;

		end % readobjectfile

		function b = deleteobjectfile(ndi_base_obj, dirname)
			% DELETEOBJECTFILE - Delete / remove the object file (or files) for NDI_BASE
			%
			% B = DELETEOBJECTFILE(NDI_BASE_OBJ, DIRNAME)
			%
			% Delete all files associated with NDI_BASE_OBJ in directory DIRNAME (full path).
			%
			% B is 1 if the process succeeds, 0 otherwise.
			%
				filename = [dirname filesep ndi_base_obj.outputobjectfilename];
				b = 1;
				try,
					delete(filename);
				catch,
					b = 0;
				end
		end

		function [obj,properties_set] = setproperties(ndi_base_obj, properties, values)
			% SETPROPERTIES - set the properties of an NDI_BASE object
			%
			% [OBJ,PROPERTIESSET] = SETPROPERTIES(NDI_BASE_OBJ, PROPERTIES, VALUES)
			%
			% Given a cell array of string PROPERTIES and a cell array of the corresponding
			% VALUES, sets the fields in NDI_BASE_OBJ and returns the result in OBJ.
			%
			% If any entries in PROPERTIES are not properties of NDI_BASE_OBJ, then 
			% that property is skipped.
			%
			% The properties that are actually set are returned in PROPERTIESSET.
			%
			% Developer note: when creating a subclass of NDI_BASE that has its own properties that
			% need to be read/written from disk, copy this method SETPROPERTIES into the new class so that
			% you will be able to set all properties (this instance can only set properties of NDI_BASE).
			%
				fn = fieldnames(ndi_base_obj);
				obj = ndi_base_obj;
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
			
		function ndi_base_obj=writeobjectfile(ndi_base_obj, dirname, locked)
			% WRITEOBJECTFILE - write the object file to a file
			% 
			% WRITEOBJECTFILE(NDI_BASE_OBJ, DIRNAME, [LOCKED])
			%
			% Writes the NDI_BASE_OBJ to a file in a manner that can be
			% read by the creator function NDI_BASE.
			%
			% Writes to the path DIRNAME/NDI_BASE_OBJ.OBJECTFILENAME
			%
			% If LOCKED is 1, then the calling function has verified a correct
			% lock on the file and WRITEOBJECTFILE shouldn't lock/unlock it.
			%
			% See also: NDI_BASE/NDI_BASE
			%
				if nargin<3,
					locked = 0;
				end;

				thisfunctionlocked = 0;
				if ~locked, % we need to lock it
					ndi_base_obj = ndi_base_obj.lock(dirname);
					thisfunctionlocked = 1;
				end

				filename = [dirname filesep ndi_base_obj.outputobjectfilename];
				fid = fopen(filename,'wb');	% files will consistently use big-endian
				if fid < 0,
					error(['Could not open the file ' filename ' for writing.']);
				end;

				ndi_base_obj.writedata2objectfile(fid);

				fclose(fid);

				if thisfunctionlocked,
					ndi_base_obj = ndi_base_obj.unlock(dirname);
				end

		end % writeobjectfile

		function writedata2objectfile(ndi_base_obj, fid)
			% WRITEDATA2OBJECTFILE - write NDI_BASE object file data to the object file FID
			%
			% WRITEDATA2OBJECTFILE(NDI_BASE_OBJ, FID)
			%
			% This function writes the data for the NDI_BASE_OBJ to the object file 
			% identifier FID.
			%
			% This function assumes the FID is open for writing and it does not close the
			% the FID. This function is normally called by WRITEOBJECTFILE and is typically
			% an internal function.
			%
				data = ndi_base_obj.stringdatatosave();
				
				for i=1:length(data),
					count = fprintf(fid,'%s\n',data{i});
					if count~=numel(data{i})+1,
						error(['Error writing to the file ' filename '.']);
					end
				end
		end % writedata2objectfile() 

		function [data, fieldnames] = stringdatatosave(ndi_base_obj)
			% STRINGDATATOSAVE - Returns a set of strings to write to file to save object information
			%
			% [DATA,FIELDNAMES] = STRINGDATATOSAVE(NDI_BASE_OBJ)
			%
			% Return a cell array of strings to save to the objectfilename.
			%
			% FIELDNAMES is a set of names of the fields/properties of the object
			% that are being stored.
			%
			% For NDI_BASE, this returns the classname, name, and the objectfilename.
			%
			% Developer note: If you create a subclass of NDI_BASE with properties, it is recommended
			% that you implement your own version of this method. If you have only properties that can be stored
			% efficiently as strings, then you will not need to include a WRITEOBJECTFILE method.
			%
				data = {class(ndi_base_obj) ndi_base_obj.objectfilename};
				fieldnames = { '', 'objectfilename' };

		end % stringdatatosave

		function fname = outputobjectfilename(ndi_base_obj)
			% OUTPUTOBJECTFILENAME - return the output file name for an NDI_BASE object
			%
			% FNAME = OUTPUTOBJECTFILENAME(NDI_BASE_OBJ)
			%
			% Returns the filename (without parent directory) to be used to save the NDI_BASE
			% object. In the NDI_BASE class, it is just NDI_BASE_OBJ.objectfilename.
			%
			%
				fname = ndi_base_obj.objectfilename;
		end % outputobjectfilename ()

                function lockfname = lockfilename(ndi_base_obj, dirname)
                        % LOCKFILENAME - the filename of the lock file that serves as a semaphore to maintain data integrity
                        %
                        % LOCKFNAME = LOCKFILENAME(NDI_BASE_OBJ, DIRNAME)
                        %
                        % Returns the filename that is used for locking the metadata and object data files.
			%
			% DIRNAME is the directory to use (full path).
                        %
                        % See also: NDI_BASE/LOCK NDI_BASE/UNLOCK NDI_BASE/LOCKFILENAME
			%
				filename = [dirname filesep ndi_base_obj.outputobjectfilename];
				lockfname = [filename '-lock'];
                end % lockfilename()

                function [ndi_base_obj, b] = lock(ndi_base_obj, dirname)
			% LOCK - lock the metadata file and object files so other processes cannot change them
			%
			% [NDI_BASEOBJ, B] = LOCK(NDI_BASEOBJ, DIRNAME)
			%
			% Attempts to obtain the lock on the object file. If it is successful,
			% B is 1. Otherwise, B is 0. DIRNAME is the directory where the file(s)
			% is(are) stored (full path).
			%
			% Note: Only a function that calls LOCK should call UNLOCK to maintain integrety of object data.
			%
			% See also: NDI_BASE/LOCK NDI_BASE/UNLOCK NDI_BASE/LOCKFILENAME

				b = 0;

				lockfid = checkout_lock_file(ndi_base_obj.lockfilename(dirname));
				if lockfid>0,
					ndi_base_obj.lockfid = lockfid;
					b = 1;
				end

                end % lock()

                function [ndi_base_obj, b] = unlock(ndi_base_obj, dirname)
			% UNLOCK - unlock the metadata file and object files so other processes can change them
			%
			% [NDI_BASE_OBJ, B] = UNLOCK(NDI_BASE_OBJ, DIRNAME)
			%
			% Removes the lock file from the NDI_BASE NDI_BASE_OBJ.
			%
			% DIRNAME is the directory where the file(s) is (are) stored (full path).
			%
			% Note: Only a function that calls LOCK should call UNLOCK to maintain integrety of metadata and object data.
			% The function returns B=1 if the operation was successful, B=0 otherwise.
			%
			% See also: NDI_BASE/LOCK NDI_BASE/UNLOCK NDI_BASE/LOCKFILENAME
				b = 1;
				if ~isempty(ndi_base_obj.lockfid),
					try,
						fclose(ndi_base_obj.lockfid);
						delete(ndi_base_obj.lockfilename(dirname));
						ndi_base_obj.lockfid = [];
					catch,
						b = 0;
					end;
				end;
                end % unlock()

	end % methods 

end
