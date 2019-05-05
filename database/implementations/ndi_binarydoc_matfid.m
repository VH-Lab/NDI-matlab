classdef ndi_binarydoc_matfid < ndi_binarydoc & fileobj

	properties, 
	end;

	methods,
		function ndi_binarydoc_matfid_obj = ndi_binarydoc_matfid(varargin)
			% NDI_BINARYDOC_MATFID - create a new NDI_BINARYDOC_MATFID object
			%
			% NDI_BINARYDOC_MATFID_OBJ = NDI_BINARYDOC_MATFID(PARAM1,VALUE1, ...)
			%
			% Follows same arguments as FILEOBJ
			%
			% See also: FILEOBJ, FILEOBJ/FILEOBJ
			%
				ndi_binarydoc_matfid_obj = ndi_binarydoc_matfid_obj@fileobj(varargin{:});
				ndi_binarydoc_matfid_obj.machineformat = 'ieee-le';
		end; % ndi_binarydoc_matfid() creator

		function ndi_binarydoc_matfid_obj = fclose(ndi_binarydoc_matfid_obj)
			% FCLOSE - close an NDI_BINARYDOC_MATFID object
			%
			% Closes the file, but also clears the fullpathfilename and other fields so the 
			% user cannot re-use the object without checking out another binary document from
			% the database.
			%
				ndi_binarydoc_matfid_obj.fclose@fileobj();
				ndi_binarydoc_matfid_obj.fullpathfilename = '';
				ndi_binarydoc_matfid_obj.permission = 'r';
		end % fclose()
	end;
end

