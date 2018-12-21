classdef nsd_binarydoc < handle
	% NSD_BINARYDOC - a binary file class that handles reading/writing
	properties (SetAccess=protected, GetAccess=public)
	end  % protected, accessible

	methods (Abstract) 
		%nsd_binarydoc_obj = nsd_binarydoc(varargin)
			% NSD_BINARYDOC - create a new NSD_BINARYDOC object
			%
			% NSD_BINARYDOC_OBJ = NSD_BINARYDOC()
			%
			% This is an abstract class, so the creator does nothing.
			%

		%end; % nsd_binarydoc()

		nsd_binarydoc_obj = fopen(nsd_binarydoc_obj)
			% FOPEN - open the NSD_BINARYDOC for reading/writing
			%
			% FOPEN(NSD_BINARYDOC_OBJ)
			%
			% Open the file record associated with NSD_BINARYDOC_OBJ.
			%

		%end; % fopen()
			
		fseek(nsd_binarydoc_obj, location, reference)
			% FSEEK - move to a location within the file stream 
			%
			% FSEEK(NSD_BINARYDOC_OBJ, LOCATION, REFERENCE)
			%
			% Moves to a LOCATION (in bytes) in a file stream.
			%
			% LOCATION is relative to a REFERENCE:
			%    'bof'  - beginning of file
			%    'cof'  - current position in file
			%    'eof'  - end of file 
			%
			% See also: FSEEK, FTELL, NSD_BINARYDOC/FTELL
		%end % fseek()

		location = ftell(nsd_binarydoc_obj)
			% FSEEK - move to a location within the file stream 
			%
			% FSEEK(NSD_BINARYDOC_OBJ)
			%
			% Returns the current LOCATION (in bytes) in a file stream.
			%
			% See also: FSEEK, FTELL, NSD_BINARYDOC/FSEEK
		%end % ftell()

		b = feof(nsd_binarydoc_obj)
			% FEOF - is an NSD_BINARYDOC at the end of file?
			%
			% B = FEOF(NSD_BINARYDOC_OBJ)
			%
			% Returns 1 if the end-of-file indicator is set on the 
			% file stream NSD_BINARYDOC_OBJ, and 0 otherwise.
			%
			% See also: FEOF, FSEEK, NSD_BINARYDOC/FSEEK
		%end % feof

		count = fwrite(nsd_binarydoc_obj, data, precision, skip)
			% FWRITE - write data to an NSD_BINARYDOC
			% FOPEN - open the NSD_BINARYDOC for reading/writing
			%
			% COUNT = FWRITE(FILENAME, PERMISSIONS)
			%
			% 
			% See also: FWRITE
		%end; % fwrite()

		[data, count] = fread(nsd_binarydoc_obj, count, precision, skip)
			% FREAD - read data from an NSD_BINARYDOC
			%
			% [DATA, COUNT] = FREAD(NSD_BINARYDOC_OBJ, COUNT, [PRECISION],[SKIP])
			%
			% Read COUNT data objects (precision PRECISION) from an NSD_BINARYDOC object.
			% The actual COUNT is returned, along with the DATA.
			%
			% See also: FREAD
		%end; % fread()

		nsd_binarydoc_obj = fclose(nsd_binarydoc_obj)
			%FCLOSE - close an NSD_BINARYDOC
			%
			% FCLOSE(NSD_BINARYDOC_OBJ)
			%
			% 

		%end; % fclose()

	end; % Abstract methods

	methods

		function delete(nsd_binarydoc_obj)
		% DELETE - close an NSD_BINARYDOC and delete its handle
		%
		% DELETE(NSD_BINARYDOC_OBJ)
		%
		% Closes an NSD_BINARYDOC (if necessary) and then deletes the handle.
		%
			fclose(nsd_binarydoc_obj);
			delete@handle(nsd_binarydoc_obj); % call superclass
		end; % delete()	

	end % methods

end
