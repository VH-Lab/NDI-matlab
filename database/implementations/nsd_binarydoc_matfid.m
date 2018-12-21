classdef nsd_binarydoc_matfid < nsd_binarydoc & fileobj

	properties, 
	end;

	methods,
		function nsd_binarydoc_matfid_obj = nsd_binarydoc_matfid(varargin)
			% NSD_BINARYDOC_MATFID - create a new NSD_BINARYDOC_MATFID object
			%
			% NSD_BINARYDOC_MATFID_OBJ = NSD_BINARYDOC_MATFID(PARAM1,VALUE1, ...)
			%
			% Follows same arguments as FILEOBJ
			%
			% See also: FILEOBJ, FILEOBJ/FILEOBJ
			%
				nsd_binarydoc_matfid_obj = nsd_binarydoc_matfid_obj@fileobj(varargin{:});
				nsd_binarydoc_matfid_obj.machineformat = 'ieee-le';
		end; % nsd_binarydoc_matfid() creator

		function nsd_binarydoc_matfid_obj = fclose(nsd_binarydoc_matfid_obj)
			% FCLOSE - close an NSD_BINARYDOC_MATFID object
			%
			% Closes the file, but also clears the fullpathfilename and other fields so the 
			% user cannot re-use the object without checking out another binary document from
			% the database.
			%
				nsd_binarydoc_matfid_obj.fclose@fileobj();
				nsd_binarydoc_matfid_obj.fullpathfilename = '';
				nsd_binarydoc_matfid_obj.permission = 'r';
		end % fclose()
	end;
end

