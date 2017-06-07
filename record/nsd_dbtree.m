class nsd_dbtree
	% NSD_DBTREE - A class that manages trees of NSD_DBLEAF objects with searchable metadata
	%
	% 
	%
	
		    % development notes: opportunties for a metadata cache, search and loading optimization and caching

	parameters (Access=protected)
		path         % String path; where NSD_DBTREE should store its files
		name         % String name; this must be like a valid Matlab variable name and not include file separators (:,/,\)
	end % parameters

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

			error('not implemented.');

		end % nsd_dbtree

		function nsd_dbtree_obj=add(nsd_dbtree_obj, newobj)
			% ADD - Add an item to an NSD_DBTREE
			%
			% NSD_DBTREE_OBJ = ADD(NSD_DBTREE_OBJ, NEWOBJ)  % or is this static??

			if ~ (isa(newobj,'nds_dbleaf') | isa(newobj,'nsd_dbtree')),
				error(['objects to be added must be descended from NSD_DBLEAF or NSD_DBTREE.']);
			end

			   % right now, we need to read all metadata and write it back; silly really, and slow
			md = metadata(nsd_dbtree_obj);
			omd = metadatastruct(newobj);
			% now have to reconcile possibly different metadata structures
			fn1 = fieldnames(md);
			fn2 = fieldnames(omd);

			% have to check for unique names in this branch
				error(['not implemented.']);
			

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

			% now write md back to disk
			writemetadata(nsd_dbtree_obj, md);
		end

		function nsd_dbtree_obj=remove(nsd_dbtree_obj, index)
			% REMOVE - Remove an item from an NSD_DBTREE
			%
			% NSD_DBTREE_OBJ = REMOVE(NSD_DBTREE_OBJ, INDEX)  % or is this static??

			error('not implemented.');
		end

	end % methods

	methods (Static)
		function md = metadata(nsd_dbtree_obj)
			% METADATA - Return the metadata from an NSD_DBTREE
			%
			%  MD = METADATA(NSD_DBTREE_OBJ);
			%
			if exist(filename(nds_dbtree_obj),'file'),
				md = loadStructArray(filename(nsd_dbtree_obj));
			else,
				md = emptystruct;
			end;

		function mds = metadatastruct(nsd_dbtree_obj)
			% METADATASTRUCT - return the metadata fields and values for an NSD_DBTREE
			%
			% MDS = METADATASTRUCT(NSD_DBTREE_OBJ)
			%
			% Returns the metadata fieldnames and values for NSD_DBTREE_OBJ.
			% This is simply MDS = struct('is_nsd_dbtree',1,'name',NAME);
				mds = struct('is_nsd_dbtree',1,'name',nsd_dbtree_obj.name);
			end
			
		function indexes = search(nsd_dbtree_obj, parameter, match)
			% SEARCH - search for a match in NSD_DBTREE metadata
			% 
			error('not implemented.');

		end % search

		function obj = load(nsd_dbtree_obj, varargin)
			% LOAD - Load an object(s) from an NSD_DBTREE
			%
			%  OBJ = LOAD(NSD_DBTREE_OBJ, INDEX)
			error('not implemented.');

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

	end % methods (Static)

	methods (Private)

		function writemetadata(nsd_dbtree_obj, metad)
			% WRITEMETADATA - write the metadata to the disk
			%
			% WRITEMETADATA(NSD_DBTREE_OBJ, metadata)
			%
			% Writes the metadata of NSD_DBTREE object NSD_DBTREE_OBJ
			% to disk.
			% 

			if nargin<2,
				metad = nsd_dbtree_obj.metadata();
			end;
			
			fname = filename(nds_dbtree_obj);
			lockfname = [fname '-lock'];
			
			% semaphore
			fid = checkout_lock_file(lockfname);
			if fid<0,
				error(['Tried to write meta data but the file was in use! Error! Delete ' lockfname ' if program was interrupted while writing.']);
			else,
				saveStructArray(filename(nsd_dbtree_obj),metad);
				fclose(fid);
				fdelete(lockfname);
			end;

		end % writemetadata()

		function fname = filename(nsd_dbtree_obj)
			% FILENAME - Return the (full path) database file name associated with an NSD_DBTREE
			%
			% FNAME = FILENAME(NSD_DBTREE_OBJ)
			%
			% Returns the filename of the metadata of an NSD_DBTREE object (full path).
			%

			fname = [nsd_dbtree_obj.path filesep nsd_dbtree_obj.name '.dbtree.nsd'];
		end % filename()
	end

end % nsd_dbtree
