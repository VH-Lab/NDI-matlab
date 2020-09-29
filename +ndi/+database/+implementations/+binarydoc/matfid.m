classdef matfid < ndi.database.binarydoc & vlt.file.fileobj

	properties,
		key            %  The key that is created when the binary doc is locked
		doc_unique_id  %  The document unique id
	end;

	methods,
		function ndi_binarydoc_matfid_obj = matfid(varargin)
			% ndi.database.binarydoc.matfid - create a new ndi.database.binarydoc.matfid object
			%
			% NDI_BINARYDOC_MATFID_OBJ = ndi.database.binarydoc.matfid(PARAM1,VALUE1, ...)
			%
			% Follows same arguments as vlt.file.fileobj
			%
			% See also: vlt.file.fileobj, vlt.file.fileobj/FILEOBJ
			%
				key = '';
				doc_unique_id = '';
				vlt.data.assign(varargin{:});
				ndi_binarydoc_matfid_obj = ndi_binarydoc_matfid_obj@vlt.file.fileobj(varargin{:});
				ndi_binarydoc_matfid_obj.machineformat = 'ieee-le';
				ndi_binarydoc_matfid_obj.key = key;
				ndi_binarydoc_matfid_obj.doc_unique_id = doc_unique_id;
		end; % ndi.database.binarydoc.matfid() creator

		function ndi_binarydoc_matfid_obj = fclose(ndi_binarydoc_matfid_obj)
			% FCLOSE - close an ndi.database.binarydoc.matfid object
			%
			% Closes the file, but also clears the fullpathfilename and other fields so the 
			% user cannot re-use the object without checking out another binary document from
			% the database.
			%
				ndi_binarydoc_matfid_obj.fclose@vlt.file.fileobj();
				ndi_binarydoc_matfid_obj.permission = 'r';
		end % fclose()
	end;
end

