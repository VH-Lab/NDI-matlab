classdef  ndi_matlabdumbjsondb < ndi_database

	properties
		db		% dumbjsondb object
	end

	methods

		function ndi_matlabdumbjsondb_obj = ndi_matlabdumbjsondb(varargin)
		% NDI_MATLABDUMBJSONDB make a new NDI_MATLABDUMBJSONDB object
		% 
		% NDI_MATLABDUMBJSONDB_OBJ = NDI_MATLABDUMBJSONDB(PATH, EXPERIMENT_UNIQUE_REFERENCE, COMMAND, ...)
		%
		% Creates a new NDI_MATLABDUMBJSONDB object.
		%
		% COMMAND can either be 'Load' or 'New'. The second argument
		% should be the full pathname of the location where the files
		% should be stored on disk.
		%
		% See also: DUMBJSONDB, DUMBJSONDB/DUMBJSONDB
			ndi_matlabdumbjsondb_obj = ndi_matlabdumbjsondb_obj@ndi_database(varargin{:});
			ndi_matlabdumbjsondb_obj.db = dumbjsondb(varargin{3:end},...
				'dirname','dumbjsondb','unique_object_id_field','ndi_document.document_unique_reference');
		end; % ndi_matlabdumbjsondb()

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
			ndi_document_obj = ndi_document(doc);
		end; % do_read

		function ndi_matlabdumbjsondb_obj = do_remove(ndi_matlabdumbjsondb_obj, ndi_document_id, versions)
			if nargin<3,
				versions = [];
			end;
			ndi_matlabdumbjsondb_obj = ndi_matlabdumbjsondb_obj.db.remove(ndi_document_id, versions);
			
		end; % do_remove

		function [ndi_document_objs,doc_versions] = do_search(ndi_matlabdumbjsondb_obj, searchoptions, searchparams)
			ndi_document_objs = {};
			[docs,doc_versions] = ndi_matlabdumbjsondb_obj.db.search(searchoptions, searchparams);
			for i=1:numel(docs),
				ndi_document_objs{i} = ndi_document(docs{i});
			end;
		end; % do_search()

		function [ndi_binarydoc_obj] = do_openbinarydoc(ndi_matlabdumbjsondb_obj, ndi_document_id, version)
			ndi_binarydoc_obj = [];
			fid = ndi_matlabdumbjsondb_obj.db.openbinaryfile(ndi_document_id, version);
			if fid>0,
				[filename,permission,machineformat,encoding] = fopen(fid);
				ndi_binarydoc_obj = ndi_binarydoc_matfid('fid',fid,'fullpathfilename',filename,...
					'machineformat',machineformat,'permission',permission);
				ndi_binarydoc_obj.frewind(); % move to beginning of the file
			end
		end; % do_binarydoc()

		function [ndi_binarydoc_matfid_obj] = do_closebinarydoc(ndi_matlabdumbjsondb_obj, ndi_binarydoc_matfid_obj)
			% DO_CLOSEBINARYDOC - close and unlock an NDI_BINARYDOC_MATFID_OBJ
			%
			% NDI_BINARYDOC_OBJ = DO_CLOSEBINARYDOC(NDI_MATLABDUMBJSONDB_OBJ, NDI_BINARYDOC_MATFID_OBJ)
			%
			% Close and unlock the binary file associated with NDI_BINARYDOC_OBJ.
			%	
                ndi_binarydoc_matfid_obj.fid
				ndi_matlabdumbjsondb_obj.db.closebinaryfile(ndi_binarydoc_matfid_obj.fid);
				ndi_binarydoc_matfid_obj.fclose(); 
		end; % do_closebinarydoc()
	end;
end
