classdef dir < ndi.dataset


	properties (GetAccess=public, SetAccess=protected)
		path    % the file path of the session
	end

	methods
        function ndi_dataset_dir_obj = dir(reference, path_name, docs)
			% ndi.dataset.dir - Create a new ndi.dataset.dir object
			%
			% D = ndi.dataset.dir(REFERENCE, PATH_NAME)
			%
			% Creates an ndi.dataset.dir object, that is, an ndi.dataset object
			% with an associated directory.
			%
			% One can also create an existing ndi.dataset.dir object with
			% 
			% D = ndi.dataset.dir(PATH_NAME)
			%
				if nargin==1,
					path_name = reference;
					ndi_dataset_dir_obj.session = ndi.session.dir(path_name);
				elseif nargin==2,
					ndi_dataset_dir_obj.session = ndi.session.dir(reference, path_name);
				elseif nargin==3, % hidden third option
					S = warning;
					warning('off');
					ndi_dataset_dir_obj.session = ndi.session.dir(reference, path_name);
					mystruct = struct(ndi_dataset_dir_obj.session); % don't do this but we need to here
					for i=1:numel(docs),
						mystruct.database.add(docs{i});
					end;
					warning(S);
					ndi_dataset_dir_obj.session = ndi.session.dir(reference, path_name);
				end;

                % Use the session.dir's path as the path for this object
                ndi_dataset_dir_obj.path = ndi_dataset_dir_obj.session.path;

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
						ndi_dataset_dir_obj.session = ndi.session.dir(ref,path_name,session_id);
					end;
				end;
		end; % dir(), creator

	end; % methods


end
