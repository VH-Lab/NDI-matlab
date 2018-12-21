classdef nsd_dbleaf_branch < nsd_dbleaf
	% NSD_DBLEAF_BRANCH - A class that manages branches of NSD_DBLEAF objects with searchable metadata
	%
	% 
	%
		    % development notes: opportunties for a metadata cache, search and loading optimization and caching

	properties (GetAccess=public,SetAccess=protected)
		path         % String path; where NSD_DBLEAF_BRANCH should store its files
		classnames   % Cell array of classes that may be stored in the branch
		isflat       % 0/1 Is this a flat branch (that is, with no subbranches allowed?)
		memory       % 0/1 Should this NSD_DBLEAF_BRANCH exist in memory rather than writing files to disk?
	end % properties
	properties (Access=protected)
		mdmemory     % metadata in memory (if memory==1)
		leaf         % cell array of leafs (leaves) if local memory is storage (that is, memory==1)
	end % parameters private

	methods
		function obj = nsd_dbleaf_branch(path, name, classnames, isflat, memory, doadd)
			% NSD_DBLEAF_BRANCH - Create a database branch of objects with searchable metadata
			% 
			% DBBRANCH = NSD_DBLEAF_BRANCH(PATH, NAME, CLASSNAMES, [ISFLAT], [MEMORY], [ADD])
			%
			% Creates an NSD_DBLEAF_BRANCH object that operates at the path PATH, has the
			% string name NAME, and may consist of elements of classes that are found
			% in CLASSNAMES. NAME may be any string. The optional argument ISFLAT is a 0/1
			% value that indicates whether NSD_DBLEAF_BRANCH objects can be added as elements to
			% DBBRANCH. The optional argument MEMORY is a 0/1 value that indicates whether this
			% this NSD_DBLEAF_BRANCH object should only store its objects in memory (1) or write objects
			% to disk as they are added (1).
			%
			% One may also use the form:
			%
			% DBBRANCH = NSD_DBLEAF_BRANCH(PARENT_BRANCH, NAME, CLASSNAMES, [ISFLAT], [MEMORY], [ADD])
			%
			% where PARENT_BRANCH is a NSD_DBLEAF_BRANCH, and PATH will be taken from that
			% object's directory name (that is, PARENT_BRANCH.DIRNAME() ). The new object
			% will be added to the parent branch PARENT_BRANCH unless ADD is 0.
			%
			% Another variation is:
			%
			% DBBRANCH = NSD_DBLEAF_BRANCH(FILENAME, 'OpenFile'), which will read in the object
			% from a filename. To developers: all NSD_DBLEAF descendents must offer this constructor.
			% 
			% DBBRANCHs are containers for NSD_DBLEAF elements.
			%

			loadfromfile = 0;
			parent = [];

			if nargin < 6, 
				doadd = 1;
			end

			if nargin<5,
				memory = 0;
			end

			if nargin<4,
				isflat = 0;
			end;

			if nargin==0, % undocumented dummy
				name = '';
				path='';
				classnames = {};
			end;

			if isa(path,'nsd_dbleaf_branch'), % is from a parent
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
			if loadfromfile,
				fullfilename = path; % path is really a full file name
				obj = obj.readobjectfile(fullfilename);
				return;
			end;
			if exist(path,'dir') | isempty(path),
				obj.path = path;
			else,
				error(['path does not exist.']);
			end;
			obj.classnames = classnames;
			obj.isflat = isflat;
			obj.memory = memory;
			obj.mdmemory = emptystruct;
			obj.leaf = {};
			if ~isempty(parent),
				potential_existing_nsd_dbleaf_branch_obj = parent.load('name',obj.name);
				if isempty(potential_existing_nsd_dbleaf_branch_obj),
					if doadd,
						parent.add(obj);
					end
				else,
					if potential_existing_nsd_dbleaf_branch_obj.isflat ~= obj.isflat | ...
						potential_existing_nsd_dbleaf_branch_obj.memory ~= obj.memory,
						error(['nsd_dbleaf_branch with name ' obj.name ' already exists with different isflat or memory parameters.']);
					end
					obj = potential_existing_nsd_dbleaf_branch_obj;                    
				end
			end;

		end % nsd_dbleaf_branch

		function md = metadata(nsd_dbleaf_branch_obj)
			% METADATA - Return the metadata from an NSD_DBLEAF_BRANCH
			%
			%  MD = METADATA(NSD_DBLEAF_BRANCH_OBJ);
			%
			if isempty(nsd_dbleaf_branch_obj.path),
				md = nsd_dbleaf_branch_obj.mdmemory;
			else,
				if exist(metadatafilename(nsd_dbleaf_branch_obj),'file'),
					md = loadStructArray(metadatafilename(nsd_dbleaf_branch_obj));
				else,
					md = emptystruct;
				end;
			end
		end % metadata

		function mds = metadatastruct(nsd_dbleaf_branch_obj)
			% METADATASTRUCT - return the metadata fields and values for an NSD_DBLEAF_BRANCH
			%
			% MDS = METADATASTRUCT(NSD_DBLEAF_BRANCH_OBJ)
			%
			% Returns the metadata fieldnames and values for NSD_DBLEAF_BRANCH_OBJ.
			%
			% This is simply MDS = struct('is_nsd_dbleaf_branch',1,'name',NAME,'objectfilename',OBJECTFILENAME);
			%
				mds = metadatastruct@nsd_dbleaf(nsd_dbleaf_branch_obj);
				mds.is_nsd_dbleaf_branch = 1;
		end

		function nsd_dbleaf_branch_obj = addreplace(nsd_dbleaf_branch_obj, newobj)
			% ADDREPLACE - Add an item to an NSD_DBLEAF_BRANCH, replacing any existing item if necessary
			%
			% NSD_DBLEAF_BRANCH_OBJ = ADDREPLACE(NSD_DBLEAF_BRANCH_OBJ, NEWOBJ)
			%
			% Adds the item NEWOBJ to the NSD_DBLEAF_BEANCH NSD_DBLEAF_BRANCH_OBJ. If an object with
			% the same name as NEWOBJ already exists in NSD_DBLEAF_BRANCH_OBJ, then it is removed first.
			%
			% See also: NSD_DBLEAF_BRANCH/ADD, NSD_DBLEAF_BRANCH/REMOVE
			%
				[indexes,md] = nsd_dbleaf_branch_obj.search('name', newobj.name);
				if ~isempty(indexes),
					for i=1:numel(indexes),
						nsd_dbleaf_branch_obj = nsd_dbleaf_branch_obj.remove(md(indexes(i)).objectfilename);
					end
				end;
				nsd_dbleaf_branch_obj = nsd_dbleaf_branch_obj.add(newobj);
		end % addreplace

		function nsd_dbleaf_branch_obj = add(nsd_dbleaf_branch_obj, newobj)
			% ADD - Add an item to an NSD_DBLEAF_BRANCH
			%
			% NSD_DBLEAF_BRANCH_OBJ = ADD(NSD_DBLEAF_BRANCH_OBJ, NEWOBJ)
			%
			% Adds the item NEWOBJ to the NSD_DBLEAF_BRANCH NSD_DBLEAF_BRANCH_OBJ.  The metadata of the branch
			% is updated and the object is written to the subdirectory of NSD_DBLEAF_BRANCH_OBJ.
			%
			% NEWOBJ must be a descendent of type NSD_DBLEAF.
			%
			% A branch may not have more than one NSD_DBLEAF with the same 'name' field.
			%
			% See also: NSD_DBLEAF_BRANCH/REMOVE, NSD_DBLEAF_BRANCH/SEARCH, NSD_DBLEAF_BRANCH/LOAD

			if ~isa(newobj,'nsd_dbleaf') 
				error(['objects to be added must be descended from NSD_DBLEAF.']);
			end

			if nsd_dbleaf_branch_obj.isflat & isa(newobj,'nsd_dbleaf_branch')
				error(['The NSD_DBLEAF_BRANCH ' nsd_dbleaf_branch_obj.name ' is flat; one cannot add branches to it.']);
			end;

			match = 0;
			for i=1:length(nsd_dbleaf_branch_obj.classnames),
				match = isa(newobj, nsd_dbleaf_branch_obj.classnames{i});
				if match, break; end;
			end;
			if ~match,
				error(['The object of class ' class(newobj) ' does not match any of the allowed classes for the NSD_DBLEAF_BRANCH.']);
			end;

			   % right now, we need to read all metadata and write it back; a bit slow, could be optimized with a cache

			% have to check for unique names in this branch
			[indexes,md] = search(nsd_dbleaf_branch_obj, 'name', newobj.name);
			if ~isempty(indexes),
				error(['NSD_DBLEAF with name ''' newobj.name ''' already exists in the NSD_DBLEAF_BRANCH ''' nsd_dbleaf_branch_obj.name '''. Names must be unique within a branch.']);
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

			% now deal with saving metadata and the object

			if nsd_dbleaf_branch_obj.memory,
				nsd_dbleaf_branch_obj.mdmemory = md;    % add md to memory
				nsd_dbleaf_branch_obj.leaf{end+1} = newobj;           % add the leaf to memory
			else,
				% write the object to our unique subdirectory
				newobj.writeobjectfile(nsd_dbleaf_branch_obj.dirname());  % add the leaf to disk

				% now write md back to disk
				nsd_dbleaf_branch_obj=nsd_dbleaf_branch_obj.writeobjectfile([],0,md);
			end;
		end

		function nsd_dbleaf_branch_obj=remove(nsd_dbleaf_branch_obj, objectfilename)
			% REMOVE - Remove an item from an NSD_DBLEAF_BRANCH
			%
			% NSD_DBLEAF_BRANCH_OBJ = REMOVE(NSD_DBLEAF_BRANCH_OBJ, OBJECTFILENAME)
			%
			% Removes the object with the object file name equal to OBJECTFILENAME  
			% from NSD_DBLEAF_BRANCH_OBJ.
			%
			% See also: NSD_DBLEAF_BRANCH/REMOVE, NSD_DBLEAF_BRANCH/SEARCH, NSD_DBLEAF_BRANCH/LOAD
			%
				[nsd_dbleaf_branch_obj,b] = nsd_dbleaf_branch_obj.lock();

				if ~b,
					error(['Tried to lock metadata but the file was in use! Error! Delete ' ...
						nsd_dbleaf_branch_obj.lockfilename(nsd_dbleaf_branch_obj.path) ...
						' if a program was interrupted while writing metadata.']);
				end;

				% ok, now we know we have the lock
				[indexes,md]=nsd_dbleaf_branch_obj.search('objectfilename',objectfilename);
				if isempty(indexes),
					nsd_dbleaf_branch_obj = nsd_dbleaf_branch_obj.unlock();
					error(['No such object ' objectfilename '.']);
				end

				tokeep = setdiff(1:numel(md),indexes);
				md = md(tokeep);
				
				if nsd_dbleaf_branch_obj.memory, 
					% update memory
					nsd_dbleaf_branch_obj.mdmemory = md;
					nsd_dbleaf_branch_obj.leaf = nsd_dbleaf_branch_obj.leaf(tokeep);
				else,
					% update the file
					nsd_dbleaf_branch_obj=nsd_dbleaf_branch_obj.writeobjectfile(nsd_dbleaf_branch_obj.path,1,md); % we have the lock
					% delete the leaf from disk
					theleaf = nsd_pickdbleaf([nsd_dbleaf_branch_obj.dirname() filesep objectfilename]);
					theleaf.deleteobjectfile(nsd_dbleaf_branch_obj.dirname());
				end

				nsd_dbleaf_branch_obj=nsd_dbleaf_branch_obj.unlock();
		end

		function nsd_dbleaf_branch_obj=update(nsd_dbleaf_branch_obj, nsd_dbleaf_obj)
			% UPDATE - update the contents of a NSD_DBLEAF object that is stored in an NSD_DBLEAF_BRANCH
			%
			% NSD_DBLEAF_BRANCH_OBJ = UPDATE(NSD_DBLEAF_BRANCH_OBJ, NSD_DBLEAF_OBJ)
			%
			% Update the record of an NSD_DBLEAF object that is already stored in a NSD_DBLEAF_BRANCH
			%

				% need to lock

				[nsd_dbleaf_branch_obj,b] = nsd_dbleaf_branch_obj.lock();

				if ~b,
					error(['Could not obtain lock on object ' nsd_dbleaf_branch_obj.objectfilename '.']);
				end

				[index,md] = search(nsd_dbleaf_branch_obj, 'objectfilename', nsd_dbleaf_obj.objectfilename);

				if isempty(index),
					nsd_dbleaf_branch_obj.unlock();
					error(['The object to be updated is not in this branch: ' nsd_dbleaf_obj.objectfilename ...
						' is not in ' nsd_dbleaf_branch_obj.objectfilename '.']);
				end;

				% we assume that metadata field identities haven't changed
				
				omd = metadatastruct(nsd_dbleaf_obj);
				md(index) = structmerge(md(index),omd);

				if nsd_dbleaf_branch_obj.memory,
					nsd_dbleaf_branch_obj.mdmemory = md;    % add md to memory
					nsd_dbleaf_branch_obj.leaf{index} = nsd_dbleaf_obj;           % add the leaf to memory
				else,
					% write the object to our unique subdirectory
					nsd_dbleaf_obj.writeobjectfile(nsd_dbleaf_branch_obj.dirname(),1);  % add the leaf to disk

					% now write md back to disk
					nsd_dbleaf_branch_obj=nsd_dbleaf_branch_obj.writeobjectfile([],1,md);
				end;

				nsd_dbleaf_branch_obj.unlock();
		end % update()
		
		function [indexes,md] = search(nsd_dbleaf_branch_obj, varargin)
			% SEARCH - search for a match in NSD_DBLEAF_BRANCH metadata
			% 
			% INDEXES = SEARCH(NSD_DBLEAF_BRANCH_OBJ, PARAM1, VALUE1, PARAM2, VALUE2, ...)
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
			%     indexes = search(nsd_dbleaf_branch_obj, 'class','nsd_spikedata');
			%     indexes = search(nsd_dbleaf_branch_obj, 'class','nsd_spike(*.)');
			%
				md = nsd_dbleaf_branch_obj.metadata();  % undocumented second output
				if isempty(md)
					indexes = [];
					return;
				end;
				indexes = 1:numel(md);
				for i=1:2:numel(varargin),
					if ~isfield(md,varargin{i}),
						error([varargin{i} ' is not a field of the metadata.']);
					end;
					if ischar(varargin{i+1}),
						tests = regexpi(eval(['{md.' varargin{i} '};']), varargin{i+1}, 'forceCellOutput');
						matches_here = ~(cellfun(@isempty, tests));
					else,
						matches_here = cellfun(@(x) eq(x,varargin{i+1}), eval(['{md.' varargin{i} '};']));
					end;
					indexes = intersect(indexes,find(matches_here));
					if isempty(indexes), break; end; % if we are out of matches, no reason to keep searching
				end;
		end % search

		function obj = load(nsd_dbleaf_branch_obj, varargin)
			% LOAD - Load an object(s) from an NSD_DBLEAF_BRANCH
			%
			% OBJ = LOAD(NSD_DBLEAF_BRANCH_OBJ, PARAM1, VALUE1, PARAM2, VALUE2, ...)
			%         or
			% OBJ = LOAD(NSD_DBLEAF_BRANCH_OBJ, INDEXES)
			%
			% Returns the object(s) in the NSD_DBLEAF_BRANCH NSD_DBLEAF_BRANCH_OBJ at index(es) INDEXES or
			% searches for an object whose metadata parameters PARAMS1, PARAMS2, and so on, match
			% VALUE1, VALUE2, and so on (see NSD_DBLEAF_BRANCH/SEARCH).
			%
			% OBJ will be a cell list of matching objects. If there are no matches, empty ([]) is returned.
			%
			% See also: NSD_DBLEAF_BRANCH/SEARCH
			% 

			md = [];
			if numel(varargin)>=2 | numel(varargin)==0,
				[indexes, md] = search(nsd_dbleaf_branch_obj,varargin{:});
			else,
				indexes = varargin{1};
			end

			if ~isempty(indexes),
				if isempty(md),
					error('check why ''indexes'' is passed here, or is it an error?');
					md = metadata(nsd_dbleaf_branch_obj,indexes);
				end;
				obj = {};
				for i=1:length(indexes),
					if ~isempty(nsd_dbleaf_branch_obj.path),
						obj{i} = nsd_pickdbleaf([nsd_dbleaf_branch_obj.dirname() filesep md(indexes(i)).objectfilename]);
					else,
						obj{i} = nsd_dbleaf_branch_obj.leaf{indexes(i)};
					end
				end
				if numel(obj)==1,
					obj = obj{1};
				end;
			else,
				obj = [];
			end;

		end % load

		function n = numitems(nsd_dbleaf_branch_obj)
			% NUMITEMS - Number of items in this level of an NSD_DBLEAF_BRANCH
			%
			% N = NUMITEMS(NSD_DBLEAF_BRANCH_OBJ)
			%
			% Returns the number of items in the NSD_DBLEAF_BRANCH object.
			%

			md = nsd_dbleaf_branch_obj.metadata();
			n = numel(md);
		end % numitems()

		function nsd_dbleaf_branch_obj = writeobjectfile(nsd_dbleaf_branch_obj, thedirname, locked, metad)
			% WRITEOBJECTFILE - write the object data to the disk
			%
			% NSD_DBLEAF_BRANCH_OBJ = WRITEOBJECTFILE(NSD_DBLEAF_BRANCH_OBJ, THEDIRNAME, [LOCKED, METADATA])
			%
			% Writes the object data of NSD_DBLEAF_BRANCH object NSD_DBLEAF_BRANCH_OBJ
			% to disk. 
			%
			% THEDIRNAME can be empty; if so, it is taken to be the PATH property of NSD_DBLEAF_BRANCH_OBJ.
			% It is here to conform to the NSD_DBLEAF/WRITEOBJECTDATA form.
			%
			% If LOCKED is 1, then the calling function has verified a correct
			% lock on the output file and WRITEOBJECTFILE shouldn't lock/unlock it.
			%
			% If METADATA is provided, it is written directly.

			if nargin<2 | isempty(thedirname),
				if nsd_dbleaf_branch_obj.memory,
					error(['This branch ''' nsd_dbleaf_branch_obj.name ''' has no path. THEDIRNAME must be provided.']);
				end;
				thedirname=nsd_dbleaf_branch_obj.path;
			end;

			if nargin<3,
				locked = 0;
			end;

			if nargin<4,
				metad = nsd_dbleaf_branch_obj.metadata();
			end;
			
			b = 1;

			% now we have to proceed in 3 steps
			% a) obtain the lock so we know nobody else is going to be writing our files
			% b) write our metadata 
			% c) if we are in memory only, write our leafs
			% d) write our own object data

			% semaphore
			if ~locked,
				[nsd_dbleaf_branch_obj,b] = nsd_dbleaf_branch_obj.lock(thedirname);
			end;

			if ~b,  % we are not successfully locked
				error(['Tried to write metadata but the file was in use! Error! Delete ' ...
					nsd_dbleaf_branch_obj.lockfilename(thedirname) ...
					' if a program was interrupted while writing metadata.']);
			end;

			if ~isempty(metad), % do not write if nothing to write
				saveStructArray(metadatafilename(nsd_dbleaf_branch_obj),metad);
			else, % and we have to delete it if it is there or loadStructArray will be unhappy
				if exist(metadatafilename(nsd_dbleaf_branch_obj),'file'),
					delete(metadatafilename(nsd_dbleaf_branch_obj));
				end;
			end;

			% now, if in memory, write leaf objects
			if nsd_dbleaf_branch_obj.memory,
				% remove our subdirectory, it is guaranteed to exist after .dirname() runs
				rmdir(nsd_dbleaf_branch_obj.dirname(thedirname),'s');
				% now add back; the subdirectory will exist on the call to .dirname() because it creates it if it doesn't exist
				for i=1:numel(nsd_dbleaf_branch_obj.leaf),
					nsd_dbleaf_branch_obj.leaf{i}.writeobjectfile(nsd_dbleaf_branch_obj.dirname(thedirname));  % add the leaf to disk
				end
			end

			% now write our object data

			nsd_dbleaf_branch_obj = writeobjectfile@nsd_dbleaf(nsd_dbleaf_branch_obj, thedirname, 1);

			if ~locked,
				[nsd_dbleaf_branch_obj,b] = nsd_dbleaf_branch_obj.unlock(thedirname);
				if b==0, error(['yikes! could not remove lock!']); end;
			end

		end % writeobjectfile()

		function [data,fieldnames] = stringdatatosave(nsd_dbleaf_branch_obj)
			% STRINGDATATOSAVE - Returns a set of strings to write to file to save object information
			%
			% [DATA,FIELDNAMES] = STRINGDATATOSAVE(NSD_DBLEAF_OBJ)
			%
			% Return a cell array of strings to save to the objectfilename
			%
			% For NSD_DBLEAF, this returns the classname, name, objectfilename, path, and classnames
			%
			% FIELDNAMES is a set of names of the fields/properties of the object
			% that are being stored.
			%
				[data,fieldnames] = stringdatatosave@nsd_dbleaf(nsd_dbleaf_branch_obj);
				data{end+1} = int2str(nsd_dbleaf_branch_obj.memory);
				fieldnames{end+1} = '$memory';
				data{end+1} = cell2str(nsd_dbleaf_branch_obj.classnames);
				fieldnames{end+1} = '$classnames';
		end % stringdatatosave

		function [obj,properties_set] = setproperties(nsd_dbleaf_branch_obj, properties, values)
			% SETPROPERTIES - set the properties of an NSD_DBLEAF_BRANCH object
			%
			% [OBJ,PROPERTIESSET] = SETPROPERTIES(NSD_DBLEAF_BRANCH_OBJ, PROPERTIES, VALUES)
			%
			% Given a cell array of string PROPERTIES and a cell array of the corresponding
			% VALUES, sets the fields in NSD_DBLEAF_BRANCH_OBJ and returns the result in OBJ.
			%
			% If any entries in PROPERTIES are not properties of NSD_DBLEAF_BRANCH_OBJ, then
			% that property is skipped.
			%
			% The properties that are actually set are returned in PROPERTIESSET.
			%
				fn = fieldnames(nsd_dbleaf_branch_obj);
				obj = nsd_dbleaf_branch_obj;
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

				ind = find(strcmp('path',properties));
				if ~isempty(ind), % need to recursively update the path of all child branches
					subdirname = obj.dirname();
					subobjs = load(obj,'name','(.*)');
					if numel(subobjs)==1, subobjs = {subobjs}; end
					for j=1:numel(subobjs),
						if isa(subobjs{j},'nsd_dbleaf_branch'),
							subobjs{j} = subobjs{j}.setproperties({'path'},{subdirname});
							obj=obj.update(subobjs{j});
						end
					end
				end

		end % setproperties()

 		function obj = readobjectfile(nsd_dbleaf_branch_obj, fname)
 			% READOBJECTFILE 
 			%
 			% NSD_DBLEAF_BRANCH_OBJ = READOBJECTFILE(NSD_DBLEAF_BRANCH_OBJ, FNAME)
 			%
 			% Reads the NSD_DBLEAF_BRANCH_OBJ from the file FNAME (full path).
 			
				obj=readobjectfile@nsd_dbleaf(nsd_dbleaf_branch_obj, fname);

				obj.path = fileparts(fname); % set path to be parent directory of fname

				% now, if in memory only, we need to read in the metadata and leafs
				if obj.memory,
					[parent,myfile]=fileparts(fname);
					obj.mdmemory = loadStructArray(obj.metadatafilename(parent));
					obj.leaf = {};
					for i=1:numel(obj.mdmemory),
						obj.leaf{i} = readobjectfile([obj.dirname(parent) filesep obj.mdmemory(i).objectfilename]);
					end
				end
			end; % readobjectfile

		function [nsd_dbleaf_branch_obj, b] = lock(nsd_dbleaf_branch_obj, thedirname)
			% LOCK - lock the metadata file and object files so other processes cannot change them
			%
			% [NSD_DBLEAF_BRANCHOBJ, B] = LOCK(NSD_DBLEAF_BRANCHOBJ, [THEDIRNAME])
			%
			% Attempts to obtain the lock on the metadata file nad object files. If it is successful,
			% B is 1. Otherwise, B is 0.
			%
			% THEDIRNAME is the directory where the lock file resides. If it is not provided, then 
			% NSD_DBLEAF_BRANCH_OBJ.path is used.
			%
			% Note: Only a function that calls LOCK should call UNLOCK to maintain integrety of metadata and object data.
			%  
			% See also: NSD_DBLEAF_BRANCH/LOCK NSD_DBLEAF_BRANCH/UNLOCK NSD_DBLEAF_BRANCH/LOCKFILENAME

			b = 0;

			if nargin<2,
				thedirname = nsd_dbleaf_branch_obj.path;
			end

			if nsd_dbleaf_branch_obj.memory,
				number_of_tries = 30;
				mytry = 0;  % try to get the lock, waiting up to 30 seconds
				while ~isempty(nsd_dbleaf_branch_obj.lockfid) & (mytry < number_of_tries),
					pause(1);
					mytry = mytry + 1;
				end;
				if isempty(nsd_dbleaf_branch_obj.lockfid),
					nsd_dbleaf_branch_obj.lockfid = 'locked';
					b = 1;
				end
			else,
				[nsd_dbleaf_branch_obj,b] = lock@nsd_dbleaf(nsd_dbleaf_branch_obj, thedirname);
			end

		end % lock()
			
		function [nsd_dbleaf_branch_obj, b] = unlock(nsd_dbleaf_branch_obj, thedirname)
			% UNLOCK - unlock the metadata file and object files so other processes can change them
			% 
			% [NSD_DBLEAF_BRANCH_OBJ, B] = UNLOCK(NSD_DBLEAF_BRANCH_OBJ)
			%
			% Removes the lock file from the NSD_DBLEAF_BRANCH NSD_DBLEAF_BRANCH_OBJ.
			%
			% Note: Only a function that calls LOCK should call UNLOCK to maintain integrety of metadata and object data.
			% The function returns B=1 if the operation was successful, B=0 otherwise.
			% 
			% See also: NSD_DBLEAF_BRANCH/LOCK NSD_DBLEAF_BRANCH/UNLOCK NSD_DBLEAF_BRANCH/LOCKFILENAME

			if nargin<2,
				thedirname = nsd_dbleaf_branch_obj.path;
			end

			b = 1;
			if ~isempty(nsd_dbleaf_branch_obj.lockfid),
				if nsd_dbleaf_branch_obj.memory,
					nsd_dbleaf_branch_obj.lockfid = [];
				else,
					[nsd_dbleaf_branch_obj,b] = unlock@nsd_dbleaf(nsd_dbleaf_branch_obj, thedirname);
				end;
			end;

		end % unlock()

		function fname = metadatafilename(nsd_dbleaf_branch_obj, usethispath)
			% FILENAME - Return the (full path) metadata database file name associated with an NSD_DBLEAF_BRANCH
			%
			% FNAME = FILENAME(NSD_DBLEAF_BRANCH_OBJ, [USETHISPATH])
			%
			% Returns the filename of the metadata of an NSD_DBLEAF_BRANCH object (full path).
			%
			% If the NSD_DBLEAF_BRANCH object is in memory only, it is necessary to provide the path
			% with USETHISPATH.
			%
				if ~nsd_dbleaf_branch_obj.memory,
					usethispath = nsd_dbleaf_branch_obj.path;
				end
				fname = [usethispath filesep nsd_dbleaf_branch_obj.objectfilename '.metadata.dbleaf_branch.nsd'];
		end % metadatafilename()

		function dname = dirname(nsd_dbleaf_branch_obj, usethispath)
			% DIRNAME - Return the (full path) database directory name where objects are stored
			%
			% DNAME = DIRNAME(NSD_DBLEAF_BRANCH_OBJ, [USETHISPATH])
			%
			% Returns the directory name of the items of an NSD_DBLEAF_BRANCH object (full path).
			%
			% If the directory does not exist, it is created.
			%
			% If the NSD_DBLEAF_BRANCH object is in memory only, it is necessary to provide the path
			% with USETHISPATH.
			%
				if ~nsd_dbleaf_branch_obj.memory,
					usethispath = nsd_dbleaf_branch_obj.path;
				elseif nargin<2, % it is a memory object and it has no path, so should return empty
					dname = ''; 
					return;
				end
				dname = [usethispath filesep nsd_dbleaf_branch_obj.objectfilename '.subdir.dbleaf_branch.nsd'];
				if ~exist(dname),
					mkdir(dname);
				end;
		end % dirname()

		function b = deleteobjectfile(nsd_dbleaf_branch_obj, thedirname)
			% DELETEOBJECTFILE - Delete / remove the object file (or files) for NSD_DBLEAF_BRANCH
			%
			% B = DELETEOBJECTFILE(NSD_DBLEAF_BRANCH_OBJ, THEDIRNAME)
			%
			% Delete all files associated with NSD_DBLEAF_BRANCH_OBJ in directory THEDIRNAME (full path).
			%
			% If no directory is given, NSD_DBLEAF_BRANCH_OBJ.PATH is used.
			%
			% B is 1 if the process succeeds, 0 otherwise.
			%
				if nargin<2 & nsd_dbleaf_branch_obj.memory,
					warning(['This branch is in memory only, so to delete any files we need to know which directory it may be stored in.']);
                    return
				elseif nargin<2,
					thedirname = nsd_dbleaf_branch_obj.path;
				end

				b = 1;
				try,
					delete(nsd_dbleaf_branch_obj.metadatafilename());
				catch,
					b = 0;
				end
				rmdir(nsd_dbleaf_branch_obj.dirname(thedirname),'s');
				b = b&deleteobjectfile@nsd_dbleaf(nsd_dbleaf_branch_obj, thedirname);
		end % deletefileobject()
	end % methods

end % nsd_dbleaf_branch
