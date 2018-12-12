classdef nsd_binaryfile < handle
	% NSD_BINARYFILE - a binary file class that handles reading/writing
	properties (SetAccess=protected, GetAccess=public)
		fid		% File identifier
		filename	% Full path filename
	end  % protected, accessible


	methods % public
		function nsd_binaryfile_obj = nsd_binaryfile(varargin)
			% NSD_BINARYFILE - create a new NSD_BINARYFILE object
			%
			% NSD_BINARYFILE_OBJ = NSD_BINARYFILE()
			%

		end; % nsd_binaryfile()

		function nsd_binaryfile_obj = fopen(nsd_binaryfile_obj, filename, permissions)
			% FOPEN - open the NSD_BINARYFILE for reading/writing
			%
			% NSD_BINARYFILE_OBJ = FOPEN(FILENAME, PERMISSIONS)
			%
			% 

		end; % fopen()
			
		function nsd_binaryfile_obj = fseek(nsd_binaryfile_obj, location, reference)

		end % fseek()

		function count = fwrite(nsd_binaryfile_obj, data, precision, skip)
			% FWRITE - write data to an NSD_BINARYFILE

		end; % fwrite()

		function [data, count] = fread(nsd_binaryfile_obj, count, precision, skip)
			% FREAD - read data from an NSD_BINARYFILE

		end; % fread()

		function nsd_binaryfile_obj = fclose(nsd_binaryfile_obj)
			%FCLOSE - close an NSD_BINARYFILE


		end; % 

	end % public methods

end
