classdef nsd_dbleaf_branch_dir < nsd_dbleaf
	% NSD_DBLEAF_BRANCH_DIR - A class that manages branches of NSD_DBLEAF objects with searchable metadata
	%
	% 
	%
		    % development notes: opportunties for a metadata cache, search and loading optimization and caching

	properties (GetAccess=public,SetAccess=protected)
		path         % String path; where NSD_DBLEAF_BRANCH_DIR should store its files
		classnames   % Cell array of classes that may be stored in the branch
		isflat       % 0/1 Is this a flat branch (that is, with no subbranches allowed?)
	end % properties
	properties (Access=protected)
		lockfid      % FID of lock file
	end % parameters private

	methods
		function obj = nsd_dbleaf_branch_dir(path, name, classnames, isflat)
			% NSD_DBLEAF_BRANCH_DIR - Create a database branch of objects with searchable metadata
			% 
			% DBBRANCH = NSD_DBLEAF_BRANCH_DIR(PATH, NAME, CLASSNAMES, [ISFLAT])
			%
			% Creates an NSD_DBLEAF_BRANCH_DIR object that operates at the path PATH, has the
			% string name NAME, and may consist of elements of classes that are found
			% in CLASSNAMES. NAME may be any string. The optional argument ISFLAT is a 0/1
			% value that indicates whether NSD_DBLEAF_BRANCH_DIR objects can be added as elements to
			% DBBRANCH.
			%
			% One may also use the form:
			%
			% DBBRANCH = NSD_DBLEAF_BRANCH_DIR(PARENT_BRANCH, NAME, CLASSNAMES)
			%
			% where PARENT_BRANCH is a NSD_DBLEAF_BRANCH_DIR, and PATH will be taken from that
			% object's directory name (that is, PARENT_BRANCH.DIRNAME() ). The new object
			% will be added to the parent branch PARENT_BRANCH.
			%
			% Another variation is:
			%
			% DBBRANCH = NSD_DBLEAF_BRANCH_DIR(FILENAME, 'OpenFile'), which will read in the object
			% from a filename. To developers: all NSD_DBLEAF descendents must offer this constructor.
			% 
			% DBBRANCHs are containers for NSD_DBLEAF elements.
			%

			empty_dummy = 0;
			loadfromfile = 0;
			parent = [];

			if nargin<4,
				isflat = 0;
			end;

			if nargin==0, % undocumented dummy
				empty_dummy = 1;
				name = '';
				path='';
				classnames = {};
			end;

			if isa(path,'nsd_dbleaf_branch_dir'), % is from a parent
				parent = path;
				path = parent.dirname();
				if parent.isflat,
					error(['Cannot add subbranch to flat branch. ' parent.name ' is a flat branch.']);
				end;
			end;

			if nargin==2 & isempty(parent), % is filename
				if ~strcmp(lower(name),lower('OpenFile')),
					error(['Unknown command: ' name '.']);
				end;
				name='';
				loadfromfile = 1;
			end;

			obj = obj@nsd_dbleaf(name);
			if empty_dummy,
				obj.path=path;
				obj.classnames=classnames;
				return;
			elseif loadfromfile,
				obj = obj.readobjectfile(path);
				return;
			end;
			if exist(path,'dir'),
				obj.path = path;
			else, error(['path does not exist.']);
			end;
			obj.classnames = classnames;
			obj.isflat = isflat;
			if ~isempty(parent), parent.add(obj); end;

		end % nsd_dbleaf_branch_dir

		function md = metadata(nsd_dbleaf_branch_dir_obj)
			% METADATA - Return the metadata from an NSD_DBLEAF_BRANCH_DIR
			%
			%  MD = METADATA(NSD_DBLEAF_BRANCH_DIR_OBJ);
			%
			if exist(filename(nsd_dbleaf_branch_dir_obj),'file'),
				md = loadStructArray(filename(nsd_dbleaf_branch_dir_obj));
			else,
				md = emptystruct;
			end
		end % metadata

		function mds = metadatastruct(nsd_dbleaf_branch_dir_obj)
			% METADATASTRUCT - return the metadata fields and values for an NSD_DBLEAF_BRANCH_DIR
			%
			% MDS = METADATASTRUCT(NSD_DBLEAF_BRANCH_DIR_OBJ)
			%
			% Returns the metadata fieldnames and values for NSD_DBLEAF_BRANCH_DIR_OBJ.
			% This is simply MDS = struct('is_nsd_dbleaf_branch_dir',1,'name',NAME,'objectfilename',OBJECTFILENAME);
				mds = metadatastruct@nsd_dbleaf(nsd_dbleaf_branch_dir_obj);
				mds.is_nsd_dbleaf_branch_dir = 1;
		end

		function nsd_dbleaf_branch_dir_obj=add(nsd_dbleaf_branch_dir_obj, newobj)
			% ADD - Add an item to an NSD_DBLEAF_BRANCH_DIR
			%
			% NSD_DBLEAF_BRANCH_DIR_OBJ = ADD(NSD_DBLEAF_BRANCH_OBJ, NEWOBJ)
			%
			% Adds the item NEWOBJ to the NSD_DBLEAF_BRANCH_DIR NSD_DBLEAF_BRANCH_OBJ.  The metadata of the branch
			% is updated and the object is written to the subdirectory of NSD_DBLEAF_BRANCH_DIR_OBJ.
			%
			% NEWOBJ must be a descendent of type NSD_DBLEAF.
			%
			% A branch may not have more than one NSD_DBLEAF with the same 'name' field.
			%
			% See also: NSD_DBLEAF_BRANCH_DIR/REMOVE, NSD_DBLEAF_BRANCH/SEARCH, NSD_DBLEAF_BRANCH/LOAD

			if ~isa(newobj,'nsd_dbleaf') 
				error(['objects to be added must be descended from NSD_DBLEAF.']);
			end

			if nsd_dbleaf_branch_dir_obj.isflat & isa(newobj,'nsd_dbleaf_branch_dir')
				error(['The NSD_DBLEAF_BRANCH_DIR ' nsd_dbleaf_branch_dir_obj.name ' is flat; one cannot add branches to it.']);
			end;

			match = 0;
			for i=1:length(nsd_dbleaf_branch_dir_obj.classnames),
				match = isa(newobj, nsd_dbleaf_branch_dir_obj.classnames{i});
				if match, break; end;
			end;
			if ~match,
				error(['The object of class ' class(newobj) ' does not match any of the allowed classes for the NSD_DBLEAF_BRANCH_DIR.']);
			end;

			   % right now, we need to read all metadata and write it back; silly really, and slow

			% have to check for unique names in this branch
			[indexes,md] = search(nsd_dbleaf_branch_dir_obj, 'name', newobj.name);
			if ~isempty(indexes),
				error(['NSD_DBLEAF with name ''' newobj.name ''' already exists in the NSD_DBLEAF_BRANCH_DIR ''' nsd_dbleaf_branch_dir_obj.name '''.']);
			end;
			
			omd = metadatastruct(newobj);
			% now have to reconcile possibly different metadata structures
			fn1 = fieldnames(md);
			fn2 = fieldnames(omd);

			if isempty(md),
				md = emptystruct(fn2{:});
			elseif ~eqlen(fn1,fn2),
				if numel(setdiff(fn1,fn2))>=1, % if we have fields in md that are not in omd, add them to omd
					omd = structmerge(md([]),omd); % now omd has empty entries for all fields of fn1 that aren't in fn2
				end;
				if numel(setdiff(fn2,fn1))>=1, % if we have fields in omd that are not in md, have to add them to md
					% we know there is at least 1 entry in md
					newmd = structmerge(omd([]),md(1));
					for i=2:numel(md),
						newmd(i) = structmerge(omd([]),md(i));
					end;
					md = newmd;
				end;
			end;
			% now we're ready to concatenate 
			md(end+1) = omd;

			% make our subdirectory if it doesn't exist
			if ~exist(nsd_dbleaf_branch_dir_obj.dirname(),'dir'),
				mkdir(nsd_dbleaf_branch_dir_obj.dirname);
			end;

			% write the object to our unique subdirectory
			newobj.writeobjectfile(nsd_dbleaf_branch_dir_obj.dirname());

			% now write md back to disk
			nsd_dbleaf_branch_dir_obj=nsd_dbleaf_branch_dir_obj.writeobjectfile([],md);
		end

		function nsd_dbleaf_branch_dir_obj=remove(nsd_dbleaf_branch_dir_obj, objectfilename)
			% REMOVE - Remove an item from an NSD_DBLEAF_BRANCH_DIR
			%
			% NSD_DBLEAF_BRANCH_DIR_OBJ = REMOVE(NSD_DBLEAF_BRANCH_OBJ, OBJECTFILENAME)
			%
			% Removes the object with the object file name equal to OBJECTFILENAME  
			% from NSD_DBLEAF_BRANCH_DIR_OBJ.
			%
			% See also: NSD_DBLEAF_BRANCH_DIR/REMOVE, NSD_DBLEAF_BRANCH/SEARCH, NSD_DBLEAF_BRANCH/LOAD
			%
			%

			[nsd_dbleaf_branch_dir_obj,b] = nsd_dbleaf_branch_dir_obj.lock();

			if ~b,
				error(['Tried to lock metadata but the file was in use! Error! Delete ' ...
					nsd_dbleaf_branch_dir_obj.lockfilename ...
					' if a program was interrupted while writing metadata.']);
			end;

			% ok, now we know we have the lock
			[indexes,md]=nsd_dbleaf_branch_dir_obj.search('objectfilename',objectfilename);
			if isempty(indexes),
				nsd_dbleaf_branch_dir_obj = nsd_dbleaf_branch_dir_obj.unlock();
				error(['No such object ' objectfilename '.']);
			end;

			md = md(setdiff(1:numel(md),indexes));
			
			nsd_dbleaf_branch_dir_obj=nsd_dbleaf_branch_dir_obj.writeobjectfile(nsd_dbleaf_branch_dir_obj.path,md,1); % we have the lock

			nsd_dbleaf_branch_dir_obj=nsd_dbleaf_branch_dir_obj.unlock();
			
		end
		
		function [indexes,md] = search(nsd_dbleaf_branch_dir_obj, varargin)
			% SEARCH - search for a match in NSD_DBLEAF_BRANCH_DIR metadata
			% 
			% INDEXES = SEARCH(NSD_DBLEAF_BRANCH_DIR_OBJ, PARAM1, VALUE1, PARAM2, VALUE2, ...)
			%
			% Searches the metadata parameters PARAM1, PARAM2, and so on, for 
			% value1, value2, and so on. If valueN is a string, then a regular expression
			% is evaluated to determine the match. If valueN is not a string, then the
			% the items must match exactly.
			%
			% Case is not considered.
			% 
			% See also: REGEXPI
			%
			% Examples:
			%     indexes = search(nsd_dbleaf_branch_dir_obj, 'class','nsd_spikedata');
			%     indexes = search(nsd_dbleaf_branch_dir_obj, 'class','nsd_spike(*.)');
			%
			md = metadata(nsd_dbleaf_branch_dir_obj);  % undocumented second output
			if isempty(md),
				indexes = [];
				return;
			end;
			indexes = 1:numel(md);
			for i=1:2:numel(varargin),
				if ~isfield(md,varargin{i}),
					error([varargin{i} ' is not a field of the metadata.']);
				end;
				if ischar(varargin{i+1}),
					tests = regexpi({getfield(md,varargin{i})}, varargin{i+1}, 'forceCellOutput');
					matches_here = ~(cellfun(@isempty, tests));
				else,
					matches_here = cellfun(@(x) eq(x,varargin{i+1}), {getfield(md,varargin{i})});
				end;
				indexes = intersect(indexes,matches_here);
				if isempty(indexes), break; end; % if we are out of matches, no reason to keep searching
			end;
		end % search

		function obj = load(nsd_dbleaf_branch_dir_obj, varargin)
			% LOAD - Load an object(s) from an NSD_DBLEAF_BRANCH_DIR
			%
			% OBJ = LOAD(NSD_DBLEAF_BRANCH_DIR_OBJ, PARAM1, VALUE1, PARAM2, VALUE2, ...)
			%         or
			% OBJ = LOAD(NSD_DBLEAF_BRANCH_DIR_OBJ, INDEXES)
			%
			% Returns the object(s) in the NSD_DBLEAF_BRANCH_DIR NSD_DBLEAF_BRANCH_OBJ at index(es) INDEXES or
			% searches for an object whose metadata parameters PARAMS1, PARAMS2, and so on, match
			% VALUE1, VALUE2, and so on (see NSD_DBLEAF_BRANCH_DIR/SEARCH).
			%
			% If more than one object is requested, then OBJ will be a cell list of matching objects.
			% Otherwise, the object will be a single element. If there are no matches, empty ([]) is returned.
			%
			% See also: NSD_DBLEAF_BRANCH_DIR/SEARCH
			% 

			md = [];
			if numel(varargin)>=2,
				[indexes, md] = search(nsd_dbleaf_branch_dir_obj,varargin{:});
			else,
				indexes = varargin{1};
			end

			if ~isempty(indexes),
				if isempty(md),
					md = metadata(nsd_dbleaf_branch_dir_obj,indexes);
				end;
				md = md(indexes);
				obj = {};
				for i=1:length(indexes),
					obj{i} = nsd_pickdbleaf([nsd_dbleaf_branch_dir_obj.dirname() filesep md(i).objectfilename]);
				end;
				if numel(obj)==1,
					obj = obj{1};
				end;
			else,
				obj = [];
			end;

		end % load

		function n = numitems(nsd_dbleaf_branch_dir_obj)
			% NUMITEMS - Number of items in this level of an NSD_DBLEAF_BRANCH_DIR
			%
			% N = NUMITEMS(NSD_DBLEAF_BRANCH_DIR_OBJ)
			%
			% Returns the number of items in the NSD_DBLEAF_BRANCH_DIR object.
			%

			md = metadata(nsd_dbleaf_branch_dir_obj);
			n = numel(md);

		end % numitems

		function nsd_dbleaf_branch_dir_obj = writeobjectfile(nsd_dbleaf_branch_dir_obj, thedirname, metad, locked)
			% WRITEOBJECTFILE - write the metadata to the disk
			%
			% NSD_DBLEAF_BRANCH_DIR_OBJ = WRITEOBJECTFILE(NSD_DBLEAF_BRANCH_OBJ, THEDIRNAME, [METADATA, LOCKED])
			%
			% Writes the object data of NSD_DBLEAF_BRANCH_DIR object NSD_DBLEAF_BRANCH_OBJ
			% to disk. If METADATA is provided, it is written directly.
			%
			% THEDIRNAME can be empty; if so, it is taken to be the PATH property of NSD_DBLEAF_BRANCH_DIR_OBJ.
			% It is here to conform to the NSD_DBLEAF/WRITEOBJECTDATA form.
			%
			% If LOCKED is 1, then the calling function has verified a correct
			% lock on the metadata file and WRITEMETADATA shouldn't lock/unlock it.
			% 

			if nargin<2 | isempty(thedirname),
				thedirname=nsd_dbleaf_branch_dir_obj.path;
			end;

			if nargin<3,
				metad = nsd_dbleaf_branch_dir_obj.metadata();
			end;

			if nargin<4,
				locked = 0;
			end;
			
			b = 1;

			% semaphore
			if ~locked,
				[nsd_dbleaf_branch_dir_obj,b] = nsd_dbleaf_branch_dir_obj.lock();
			end;

			if ~b,  % we are not successfully locked
				error(['Tried to write metadata but the file was in use! Error! Delete ' ...
					nsd_dbleaf_branch_dir_obj.lockfilename ...
					' if a program was interrupted while writing metadata.']);
			else,
				if ~isempty(metad), % do not write if nothing to write
					saveStructArray(filename(nsd_dbleaf_branch_dir_obj),metad);
				else, % and we have to delete it if it is there or loadStructArray will be unhappy
					if exist(filename(nsd_dbleaf_branch_dir_obj),'file'),
						delete(filename(nsd_dbleaf_branch_dir_obj));
					end;
				end;
				if ~locked,
					[nsd_dbleaf_branch_dir_obj,b] = nsd_dbleaf_branch_dir_obj.unlock();
					if b==0, error(['yikes! could not delete lock file!']); end;
				end
			end;

			% now write our object data

			nsd_dbleaf_branch_dir_obj = writeobjectfile@nsd_dbleaf(nsd_dbleaf_branch_dir_obj, thedirname);

		end % writeobjectfile()

		function data = stringdatatosave(nsd_dbleaf_branch_dir_obj)
			% STRINGDATATOSAVE - Returns a set of strings to write to file to save object information
			%
			% DATA = STRINGDATATOSAVE(NSD_DBLEAF_OBJ)
			%
			% Return a cell array of strings to save to the objectfilename
			%
			% For NSD_DBLEAF, this returns the classname, name, objectfilename, path, and classnames
			%
				data = stringdatatosave@nsd_dbleaf(nsd_dbleaf_branch_dir_obj);
				data{end+1} = nsd_dbleaf_branch_dir_obj.path;
				data{end+1} = cell2str(nsd_dbleaf_branch_dir_obj.classnames);
		end % stringdatatosave

		function obj = readobjectfile(nsd_dbleaf_branch_dir_obj, fname)
			% READOBJECTFILE 
			%
			% NSD_DBLEAF_BRANCH_DIR_OBJ = READOBJECTFILE(NSD_DBLEAF_BRANCH_OBJ, FNAME)
			%
			% Reads the NSD_DBLEAF_BRANCH_DIR_OBJ from the file FNAME.
			
				fid = fopen(fname,'rb');  % consistently use big-endian
				if fid<0,
					error(['Could not open the file ' filename ' for reading.']);
				end;

				classname = fgetl(fid);

				if strcmp(classname,'nsd_dbleaf_branch_dir'),
					% we have a plain nsd_dbleaf_branch_dir object, let's read it
					obj = nsd_dbleaf_branch_dir_obj;
					obj.name = fgetl(fid);
					obj.objectfilename = fgetl(fid);
					obj.path = fgetl(fid);
					obj.classnames = eval(fgetl(fid));
                                        fclose(fid);
                                else,
                                        fclose(fid);
					error(['Not a valid NSD_DBLEAF_BRANCH_DIR file: ' fname '.']);
                                end;
		end; % readobjectfile

		function [nsd_dbleaf_branch_dir_obj, b] = lock(nsd_dbleaf_branch_dir_obj)
			% LOCK - lock the metadata file and object files so other processes cannot change them
			%
			% [NSD_DBLEAF_BRANCH_DIROBJ, B] = LOCK(NSD_DBLEAF_BRANCHOBJ)
			%
			% Attempts to obtain the lock on the metadata file nad object files. If it is successful,
			% B is 1. Otherwise, B is 0.
			%
			% Note: Only a function that calls LOCK should call UNLOCK to maintain integrety of metadata and object data.
			%  
			% See also: NSD_DBLEAF_BRANCH_DIR/LOCK NSD_DBLEAF_BRANCH/UNLOCK NSD_DBLEAF_BRANCH/LOCKFILENAME

			b = 0;
			if isempty(nsd_dbleaf_branch_dir_obj.lockfid),
				lockfid = checkout_lock_file(nsd_dbleaf_branch_dir_obj.lockfilename());
				if lockfid>0,
					nsd_dbleaf_branch_dir_obj.lockfid = lockfid;
					b = 1;
				end;
			end;

		end % lock()
			
		function [nsd_dbleaf_branch_dir_obj, b] = unlock(nsd_dbleaf_branch_dir_obj)
			% UNLOCK - unlock the metadata file and object files so other processes can change them
			% 
			% [NSD_DBLEAF_BRANCH_DIR_OBJ, B] = UNLOCK(NSD_DBLEAF_BRANCH_OBJ)
			%
			% Removes the lock file from the NSD_DBLEAF_BRANCH_DIR NSD_DBLEAF_BRANCH_OBJ.
			%
			% Note: Only a function that calls LOCK should call UNLOCK to maintain integrety of metadata and object data.
			% The function returns B=1 if the operation was successful, B=0 otherwise.
			% 
			% See also: NSD_DBLEAF_BRANCH_DIR/LOCK NSD_DBLEAF_BRANCH/UNLOCK NSD_DBLEAF_BRANCH/LOCKFILENAME

			b = 1;
			if ~isempty(nsd_dbleaf_branch_dir_obj.lockfid),
				try,
					fclose(nsd_dbleaf_branch_dir_obj.lockfid);
					delete(nsd_dbleaf_branch_dir_obj.lockfilename());
					nsd_dbleaf_branch_dir_obj.lockfid = [];
				catch,
					b = 0;
				end;
			end;

		end % unlock()

		function lockfname = lockfilename(nsd_dbleaf_branch_dir_obj)
			% LOCKFILENAME - the filename of the lock file that serves as a semaphore to maintain data integrity
			%
			% LOCKFNAME = LOCKFILENAME(NSD_DBLEAF_BRANCH_DIR_OBJ)
			%
			% Returns the filename that is used for locking the metadata and object data files.
			%
			% See also: NSD_DBLEAF_BRANCH_DIR/LOCK NSD_DBLEAF_BRANCH/UNLOCK NSD_DBLEAF_BRANCH/LOCKFILENAME

				fname = filename(nsd_dbleaf_branch_dir_obj);
				lockfname = [fname '-lock'];

		end % lockfilename()
			
		function fname = filename(nsd_dbleaf_branch_dir_obj)
			% FILENAME - Return the (full path) database file name associated with an NSD_DBLEAF_BRANCH_DIR
			%
			% FNAME = FILENAME(NSD_DBLEAF_BRANCH_DIR_OBJ)
			%
			% Returns the filename of the metadata of an NSD_DBLEAF_BRANCH_DIR object (full path).
			%

			fname = [nsd_dbleaf_branch_dir_obj.path filesep nsd_dbleaf_branch_dir_obj.objectfilename '.metadata.dbleaf_branch.nsd'];
		end % filename()

		function dname = dirname(nsd_dbleaf_branch_dir_obj)
			% DIRNAME - Return the (full path) database directory name where objects are stored
			%
			% DNAME = DIRNAME(NSD_DBLEAF_BRANCH_DIR_OBJ)
			%
			% Returns the directory name of the items of an NSD_DBLEAF_BRANCH_DIR object (full path).
			%

			dname = [nsd_dbleaf_branch_dir_obj.path filesep 'subdir' nsd_dbleaf_branch_dir_obj.objectfilename '.dbleaf_branch.nsd'];
		end % dirname()
	end % methods

end % nsd_dbleaf_branch_dir
