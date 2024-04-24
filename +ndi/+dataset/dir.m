classdef dir < ndi.dataset

	methods
		function ndi_dataset_dir_obj = dir(reference,path,docs)
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
				elseif nargin==3, % hidden third option
					S = warning;
					warning('off');
					ndi_dataset_dir_obj.session = ndi.session.dir(reference,path);
					mystruct = struct(ndi_dataset_dir_obj.session); % don't do this but we need to here
					for i=1:numel(docs),
						mystruct.database.add(docs{i});
					end;
					warning(S);
					ndi_dataset_dir_obj.session = ndi.session.dir(reference,path);
				end;

				q = ndi.query('','isa','dataset_session_info');
				d = ndi_dataset_dir_obj.database_search(q);
				if ~isempty(d),
					if numel(d)>1,
						error(['More than one dataset_session_info object found in dataset.']);
					end;
					session_id = d{1}.document_properties.base.session_id;
					q2 = ndi.query('','isa','session') & ndi.query('base.session_id','exact_string',session_id);
					d2 = ndi_dataset_dir_obj.database_search(q2);
					if ~isempty(d2),
						ref = d2{1}.document_properties.session.reference;
						ndi_dataset_dir_obj.session = ndi.session.dir(ref,ndi_dataset_dir_obj.session.path,session_id);
					end;
				end;
		end; % dir(), creator

	end; % methods


end
