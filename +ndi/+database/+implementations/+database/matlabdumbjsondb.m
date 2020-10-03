classdef  matlabdumbjsondb < ndi.database

	properties
		db		% vlt.file.dumbjsondb object
	end

	methods

		function ndi_matlabdumbjsondb_obj = matlabdumbjsondb(varargin)
		% ndi.database.implementations.database.matlabdumbjsondb make a new ndi.database.implementations.database.matlabdumbjsondb object
		% 
		% NDI_MATLABDUMBJSONDB_OBJ = ndi.database.implementation.database.matlabdumbjsondb(PATH, SESSION_UNIQUE_REFERENCE, COMMAND, ...)
		%
		% Creates a new ndi.database.implementations.database.matlabdumbjsondb object.
		%
		% COMMAND can either be 'Load' or 'New'. The second argument
		% should be the full pathname of the location where the files
		% should be stored on disk.
		%
		% See also: vlt.file.dumbjsondb, vlt.file.dumbjsondb/DUMBJSONDB
			ndi_matlabdumbjsondb_obj = ndi_matlabdumbjsondb_obj@ndi.database(varargin{:});
			ndi_matlabdumbjsondb_obj.db = vlt.file.dumbjsondb(varargin{3:end},...
				'dirname','dumbjsondb','unique_object_id_field','ndi_document.id');
		end; % ndi.database.implementations.database.matlabdumbjsondb()

	end 

	methods, % public
		function docids = alldocids(ndi_matlabdumbjsondb_obj)
			% ALLDOCIDS - return all document unique reference numbers for the database
			%
			% DOCIDS = ALLDOCIDS(NDI_MATLABDUMBJSONDB_OBJ)
			%
			% Return all document unique reference strings as a cell array of strings. If there
			% are no documents, empty is returned.
			%
				docids = ndi_matlabdumbjsondb_obj.db.alldocids();
		end; % alldocids()
	end;

	methods (Access=protected),

		function ndi_matlabdumbjsondb_obj = do_add(ndi_matlabdumbjsondb_obj, ndi_document_obj, add_parameters)
			namevaluepairs = {};
			fn = fieldnames(add_parameters);
			for i=1:numel(fn), 
				if strcmpi(fn{i},'Update'),
					namevaluepairs{end+1} = 'Overwrite';
					namevaluepairs{end+1} = getfield(add_parameters,fn{i});
				end;
			end;
			
			ndi_matlabdumbjsondb_obj.db = ndi_matlabdumbjsondb_obj.db.add(ndi_document_obj.document_properties, namevaluepairs{:});
		end; % do_add

		function [ndi_document_obj, version] = do_read(ndi_matlabdumbjsondb_obj, ndi_document_id, version);
			if nargin<3,
				version = [];
			end;
			[doc, version] = ndi_matlabdumbjsondb_obj.db.read(ndi_document_id, version);
			ndi_document_obj = ndi.document(doc);
		end; % do_read

		function ndi_matlabdumbjsondb_obj = do_remove(ndi_matlabdumbjsondb_obj, ndi_document_id, versions)
			if nargin<3,
				versions = [];
			end;
			ndi_matlabdumbjsondb_obj = ndi_matlabdumbjsondb_obj.db.remove(ndi_document_id, versions);
			
		end; % do_remove

		function [ndi_document_objs,doc_versions] = do_search(ndi_matlabdumbjsondb_obj, searchoptions, searchparams)
			if isa(searchparams,'ndi.query'),
				searchparams = searchparams.to_searchstructure;
				if 0, % display
					disp('search params');
					for i=1:numel(searchparams),
						searchparams(i),
						searchparams(i).param1,
						searchparams(i).param2,
					end
				end;
			end;
			ndi_document_objs = {};
			[docs,doc_versions] = ndi_matlabdumbjsondb_obj.db.search(searchoptions, searchparams);
			for i=1:numel(docs),
				ndi_document_objs{i} = ndi.document(docs{i});
			end;
		end; % do_search()

		function [ndi_binarydoc_obj, key] = do_openbinarydoc(ndi_matlabdumbjsondb_obj, ndi_document_id, version)
			ndi_binarydoc_obj = [];
			[fid, key] = ndi_matlabdumbjsondb_obj.db.openbinaryfile(ndi_document_id, version);
			if fid>0,
				[filename,permission,machineformat,encoding] = fopen(fid);
				ndi_binarydoc_obj = ndi.database.implementations.binarydoc.matfid('fid',fid,'fullpathfilename',filename,...
					'machineformat',machineformat,'permission',permission, 'doc_unique_id', ndi_document_id, 'key', key);
				ndi_binarydoc_obj.frewind(); % move to beginning of the file
			end
		end; % do_binarydoc()

		function [ndi_binarydoc_matfid_obj] = do_closebinarydoc(ndi_matlabdumbjsondb_obj, ndi_binarydoc_matfid_obj)
			% DO_CLOSEBINARYDOC - close and unlock an NDI_BINARYDOC_MATFID_OBJ
			%
			% NDI_BINARYDOC_OBJ = DO_CLOSEBINARYDOC(NDI_MATLABDUMBJSONDB_OBJ, NDI_BINARYDOC_MATFID_OBJ, KEY, NDI_DOCUMENT_ID)
			%
			% Close and unlock the binary file associated with NDI_BINARYDOC_OBJ.
			%	
				ndi_matlabdumbjsondb_obj.db.closebinaryfile(ndi_binarydoc_matfid_obj.fid, ...
					ndi_binarydoc_matfid_obj.key, ndi_binarydoc_matfid_obj.doc_unique_id);
				ndi_binarydoc_matfid_obj.fclose(); 
		end; % do_closebinarydoc()
	end;
end
