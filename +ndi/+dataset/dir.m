classdef dir < ndi.dataset

	methods
		function ndi_dataset_dir_obj = dir(reference,path)
			% ndi.dataset.dir - Create a new ndi.dataset.dir object
			%
			% D = ndi.dataset.dir(REFERENCE, PATH)
			%
			% Creates an ndi.dataset.dir object, that is, an ndi.dataset object
			% with an associated directory.
			%
			% One can also an existing ndi.dataset.dir object with
			% 
			% D = ndi.dataset.dir(PATH)
			%
				if nargin==1,
					path_arg = reference;
					ndi_dataset_dir_obj.session = ndi.session.dir(path_arg);
				elseif nargin==2,
					ndi_dataset_dir_obj.session = ndi.session.dir(reference,path);
				end;

		end; % dir(), creator

	end; % methods


end
