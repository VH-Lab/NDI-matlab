classdef nsd_dbtree < nsd_dbleaf
	% NSD_DBTREE - A class that manages trees of NSD_DBLEAF objects with searchable metadata
	%
	% 
	%
		    % development notes: opportunties for a metadata cache, search and loading optimization and caching

	properties (GetAccess=public,SetAccess=protected)
		path         % String path; where NSD_DBTREE should store its files
		classnames   % Cell array of classes that may be stored in the tree
	end % properties
	properties (Access=protected)
		lockfid      % FID of lock file
	end % parameters private

	methods
		function obj = nsd_dbtree(path, name, classnames)
			% NSD_DBTREE - Create a database tree of objects with searchable metadata
			% 
			% DBTREE = NSD_DBTREE(PATH, NAME, CLASSNAMES)
			%
			% Creates an NSD_DBTREE object that operates at the path PATH, has the
			% string name NAME, and may consist of elements of classes that are found
			% in CLASSNAMES.
			%
			% NAME must be like a valid Matlab variable name, except that Matlab keywords
			% are allowed, and the name cannot include any of the file separators that
			% are employed on common platforms (':','/','\').
			%
			% DBTREEs are containers for NSD_DBLEAF elements.
			%

			obj = obj@nsd_dbleaf(name);
			if exist(path,'dir'),
				obj.path = path;
			end;
			obj.classnames = classnames;

		end % nsd_dbtree

		function md = metadata(nsd_dbtree_obj)
			% METADATA - Return the metadata from an NSD_DBTREE
			%
			%  MD = METADATA(NSD_DBTREE_OBJ);
			%
			if exist(filename(nsd_dbtree_obj),'file'),
				md = loadStructArray(filename(nsd_dbtree_obj));
			else,
				md = emptystruct;
			end
		end % metadata

		function mds = metadatastruct(nsd_dbtree_obj)
			% METADATASTRUCT - return the metadata fields and values for an NSD_DBTREE
			%
			% MDS = METADATASTRUCT(NSD_DBTREE_OBJ)
			%
			% Returns the metadata fieldnames and values for NSD_DBTREE_OBJ.
			% This is simply MDS = struct('is_nsd_dbtree',1,'name',NAME);
				mds = struct('is_nsd_dbtree',1,'name',nsd_dbtree_obj.name);
		end

		function nsd_dbtree_obj=add(nsd_dbtree_obj, newobj)
			% ADD - Add an item to an NSD_DBTREE
			%
			% NSD_DBTREE_OBJ = ADD(NSD_DBTREE_OBJ, NEWOBJ)
			%
			% Adds the item NEWOBJ to the NSD_DBTREE NSD_DBTREE_OBJ.  The metadata of the tree
			% is updated and the object is written to the subdirectory of NSD_DBTREE_OBJ.
			%
			% NEWOBJ must be a descendent of type NSD_DBLEAF.
			%
			% See also: NSD_DBTREE/REMOVE, NSD_DBTREE/SEARCH, NSD_DBTREE/LOAD

			if ~ (isa(newobj,'nsd_dbleaf') | isa(newobj,'nsd_dbtree')),
				error(['objects to be added must be descended from NSD_DBLEAF or NSD_DBTREE.']);
			end

			match = 0;
			for i=1:length(nsd_dbtree_obj.classnames),
				match = isa(newobj, nsd_dbtree_obj.classnames{i});
				if match, break; end;
			end;
			if ~match,
				error(['The object of class ' class(newobj) ' does not match any of the allowed classes for the NSD_DBTREE.']);
			end;

			   % right now, we need to read all metadata and write it back; silly really, and slow
			md = metadata(nsd_dbtree_obj);
			omd = metadatastruct(newobj);
			% now have to reconcile possibly different metadata structures
			fn1 = fieldnames(md);
			fn2 = fieldnames(omd);

			% have to check for unique names in this branch
			indexes = search(nsd_dbtree_obj, 'name', newobj.name);
			if ~isempty(indexes),
				error(['NSD_DBLEAF with name ' newobj.name ' already exists in the NSD_DBTREE' nsd_dbtree_obj.name]);
			end;
			
			if isempty(md),
				md = emptystruct(fn2);
			elseif ~eqlen(fn1,fn2),
				if numel(setdiff(fn1,fn2))>1, % if we have fields in md that are not in omd, add them to omd
					omd = structmerge(md([]),omd); % now omd has empty entries for all fields of fn1 that aren't in fn2
				end;
				if numel(setdiff(fn2,fn1))>1, % if we have fields in omd that are not in md, have to add them to md
					% we know there is at least 1 entry in md
					newmd = structmerge(omd([]),md(1));
					for i=2:numel(md),
						newmd(i) = structmerge(omd([]),md(i));
					end;
				end;
			end;
			% now we're ready to concatenate 
			md(end+1) = omd;

			% make our subdirectory if it doesn't exist
			try, mkdir(nsd_dbtree_obj.dirname); end;

			% write the object to our unique subdirectory
			newobj.writeobjectfile(nsd_dbtree_obj.dirname());

			% now write md back to disk
			nsd_dbtree_obj=nsd_dbtree_obj.writemetadata(md);
		end

		function nsd_dbtree_obj=remove(nsd_dbtree_obj, objectfilename)
			% REMOVE - Remove an item from an NSD_DBTREE
			%
			% NSD_DBTREE_OBJ = REMOVE(NSD_DBTREE_OBJ, OBJECTFILENAME)
			%
			% Removes the object with the object file name equal to OBJECTFILENAME  
			% from NSD_DBTREE_OBJ.
			%
			% See also: NSD_DBTREE/REMOVE, NSD_DBTREE/SEARCH, NSD_DBTREE/LOAD
			%
			%

			[nsd_dbtree_obj,b] = nsd_dbtree_obj.lock();

			if ~b,
				error(['Tried to lock metadata but the file was in use! Error! Delete ' ...
					nsd_dbtree_obj.lockfilename ...
					' if a program was interrupted while writing metadata.']);
			end;

			% ok, now we know we have the lock
			[indexes,md]=nsd_dbtree_obj.search('objectfilename',objectfilename);
			if isempty(indexes),
				nsd_dbtree_obj = nsd_dbtree_obj.unlock();
				error(['No such object ' objectfilename '.']);
			end;

			md = md(setdiff(1:numel(md),indexes));
			
			nsd_dbtree_obj=nsd_dbtree_obj.writemetadata(md,1); % we have the lock

			nsd_dbtree_obj=nsd_dbtree_obj.unlock();
			
		end
		
		function [indexes,md] = search(nsd_dbtree_obj, varargin)
			% SEARCH - search for a match in NSD_DBTREE metadata
			% 
			% INDEXES = SEARCH(NSD_DBTREE_OBJ, PARAM1, VALUE1, PARAM2, VALUE2, ...)
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
			%     indexes = search(nsd_dbtree_obj, 'class','nsd_spikedata');
			%     indexes = search(nsd_dbtree_obj, 'class','nsd_spike(*.)');
			%
			md = metadata(nsd_dbtree_obj);  % undocumented second output
			indexes = 1:numel(md);
			for i=1:2:numel(varargin),
				if ischar(varargin{i+1}),
					tests = regexpi({getfield(md,varargin{i})}, varargin{i+1}, 'forceCellOutput');
					matcheshere = ~(cellfun(@isempty, tests));
				else,
					matcheshere = cellfun(@(x) eq(x,varargin{i+1}), {getfield(md,varargin{i})});
				end;
				indexes = intersect(matches,matches_here);
				if isempty(indexes), break; end; % if we are out of matches, no reason to keep searching
			end;
		end % search

		function obj = load(nsd_dbtree_obj, varargin)
			% LOAD - Load an object(s) from an NSD_DBTREE
			%
			% OBJ = LOAD(NSD_DBTREE_OBJ, PARAM1, VALUE1, PARAM2, VALUE2, ...)
			%         or
			% OBJ = LOAD(NSD_DBTREE_OBJ, INDEXES)
			%
			% Returns the object(s) in the NSD_DBTREE NSD_DBTREE_OBJ at index(es) INDEXES or
			% searches for an object whose metadata parameters PARAMS1, PARAMS2, and so on, match
			% VALUE1, VALUE2, and so on (see NSD_DBTREE/SEARCH).
			%
			% If more than one object is requested, then OBJ will be a cell list of matching objects.
			% Otherwise, the object will be a single element. If there are no matches, empty ([]) is returned.
			%
			% See also: NSD_DBTREE/SEARCH
			% 

			md = [];
			if numel(varargin)>=2,
				[indexes, md] = search(nsd_dbtree_obj,varargin{:});
			else,
				indexes = varargin{1};
			end

			if ~isempty(indexes),
				if isempty(md),
					md = metadata(nsd_dbtree_obj,indexes);
				end;
				md = md(indexes);
				obj = {};
				for i=1:length(indexes),
					obj{i} = nsd_leaf([nsd_dbtree_obj.path filesep md(i).objectfilename]);
				end;
				if numel(obj)==1,
					obj = obj{1};
				end;
			else,
				obj = [];
			end;

		end % load

		function n = numitems(nsd_dbtree_obj)
			% NUMITEMS - Number of items in this level of an NSD_DBTREE
			%
			% N = NUMITEMS(NSD_DBTREE_OBJ)
			%
			% Returns the number of items in the NSD_DBTREE object.
			%

			md = metadata(nsd_dbtree_obj);
			n = numel(md);

		end % numitems

	end % methods

	methods (Access=private)

		function nsd_dbtree_ibj = writemetadata(nsd_dbtree_obj, metad, locked)
			% WRITEMETADATA - write the metadata to the disk
			%
			% NSD_DBTREE_OBJ = WRITEMETADATA(NSD_DBTREE_OBJ, [METADATA, LOCKED])
			%
			% Writes the metadata of NSD_DBTREE object NSD_DBTREE_OBJ
			% to disk. If METADATA is provided, it is written directly.
			%
			% If LOCKED is 1, then the calling function has verified a correct
			% lock on the metadata file and WRITEMETADATA shouldn't lock/unlock it.
			% 

			if nargin<2,
				metad = nsd_dbtree_obj.metadata();
			end;

			if nargin<3,
				locked = 0;
			end;
			
			% semaphore
			if ~locked,
				[nsd_dbtree_obj,b] = nsd_dbtree_obj.lock();
			end;
			if ~b,
				error(['Tried to write metadata but the file was in use! Error! Delete ' ...
					nsd_dbtree_obj.lockfilename ...
					' if a program was interrupted while writing metadata.']);
			else,
				saveStructArray(filename(nsd_dbtree_obj),metad);
				if ~locked,
					nsd_dbtree_obj = nsd_dbtree_obj.unlock();
				end
			end;

		end % writemetadata()

		function [nsd_dbtree_obj, b] = lock(nsd_dbtree_obj)
			% LOCK - lock the metadata file and object files so other processes cannot change them
			%
			% [NSD_DBTREEOBJ, B] = LOCK(NSD_DBTREEOBJ)
			%
			% Attempts to obtain the lock on the metadata file nad object files. If it is successful,
			% B is 1. Otherwise, B is 0.
			%
			% Note: Only a function that calls LOCK should call UNLOCK to maintain integrety of metadata and object data.
			%  
			% See also: NSD_DBTREE/LOCK NSD_DBTREE/UNLOCK NSD_DBTREE/LOCKFILENAME

			b = 0;
			if isempty(nsd_dbtree_obj.lockfid),
				lockfid = checkout_lock_file(nsd_dbtree_obj.lockfilename());
				if lockfid>0,
					nsd_dbtree_obj.lockfid = lockfid;
					b = 1;
				end;
			end;

		end % lock()
			
		function [nsd_dbtree_obj, b] = unlock(nsd_dbtree_obj)
			% UNLOCK - unlock the metadata file and object files so other processes can change them
			% 
			% [NSD_DBTREE_OBJ, B] = UNLOCK(NSD_DBTREE_OBJ)
			%
			% Removes the lock file from the NSD_DBTREE NSD_DBTREE_OBJ.
			%
			% Note: Only a function that calls LOCK should call UNLOCK to maintain integrety of metadata and object data.
			% The function returns B=1 if the operation was successful, B=0 otherwise.
			% 
			% See also: NSD_DBTREE/LOCK NSD_DBTREE/UNLOCK NSD_DBTREE/LOCKFILENAME

			b = 1;
			if ~isempty(nsd_dbtree_obj.lockfid),
				try,
					close(nsd_dbtree_obj.lockfid);
					delete(nsd_dbtree_obj.lockfilename());
					nsd_dbtree_obj.lockfid = [];
				catch,
					b = 0;
				end;
			end;

		end % unlock()

		function lockfname = lockfilename(nsd_dbtree_obj)
			% LOCKFILENAME - the filename of the lock file that serves as a semaphore to maintain data integrity
			%
			% LOCKFNAME = LOCKFILENAME(NSD_DBTREE_OBJ)
			%
			% Returns the filename that is used for locking the metadata and object data files.
			%
			% See also: NSD_DBTREE/LOCK NSD_DBTREE/UNLOCK NSD_DBTREE/LOCKFILENAME

				fname = filename(nds_dbtree_obj);
				lockfname = [fname '-lock'];

		end % lockfilename()
			
		function fname = filename(nsd_dbtree_obj)
			% FILENAME - Return the (full path) database file name associated with an NSD_DBTREE
			%
			% FNAME = FILENAME(NSD_DBTREE_OBJ)
			%
			% Returns the filename of the metadata of an NSD_DBTREE object (full path).
			%

			fname = [nsd_dbtree_obj.path filesep nsd_dbtree_obj.objectfilename '.dbtree.nsd'];
		end % filename()

		function dname = dirname(nsd_dbtree_obj)
			% DIRNAME - Return the (full path) database directory name where objects are stored
			%
			% DNAME = DIRNAME(NSD_DBTREE_OBJ)
			%
			% Returns the directory name of the items of an NSD_DBTREE object (full path).
			%

			dname = [nsd_dbtree_obj.path filesep 'subdir' nsd_dbtree_obj.objectfilename '.dbtree.nsd'];
		end % dirname()
	end % methods (static)

end % nsd_dbtree
