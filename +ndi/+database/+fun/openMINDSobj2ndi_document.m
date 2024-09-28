function d = openMINDSobj2ndi_document(openmindsObj, session_id, dependency_type, dependency_value, varargin)
% OPENMINDSOBJ2NDI_DOCUMENT - openMinds objects to set of ndi.document objects
%
% D = ndi.database.fun.openMINDSobj2ndi_document(OPENMINDS_OBJ, SESSION_ID, [DEPENDENCY_TYPE], [DEPENDENCY_VALUE])
%
% Convert a cell array of openMINDS objects to a set of ndi.document objects.
% D is a cell array of ndi.document objects. If the document is requested to be of a particular
% DEPENDENCY_TYPE ('subject', 'element'), then the corresponding dependency is set to
% DEPENDENCY_VALUE.
%
% Example 1:
%   p = personWithTwoAffiliations(); % openMINDS library function
%   session_id = S.id(); % get the id of an ndi.session S
%   d = ndi.database.fun.openMINDSobj2ndi_document(p, session_id);
%
% Example 2:
%   s = openminds.controlledterms.Species('name','Mustela putorius furo','preferredOntologyIdentifier','NCBI:txid9669');
%   session_id = S.id(); % get the id of an ndi.session S
%   subject_docs = S.database_search(ndi.query('','isa','subject'));
%   d = ndi.database.fun.openMINDSobj2ndi_document(s, session_id, 'subject', subject_docs{1}.id());
% 


if ~iscell(openmindsObj),
    newcell = {};
    for i=1:numel(openmindsObj)
        newcell{i} = openmindsObj(i);
    end;
    openmindsObj = newcell;
end;

s = ndi.database.fun.openMINDSobj2struct(openmindsObj);

if nargin<3,
	dependency_type = '';
end;

if nargin<4,
	dependency_value = '';
end;

if ~isempty(dependency_type) & isempty(dependency_value),
	error(['DEPENDENCY_VALUE must not be empty if DEPENDENCY_TYPE is given.']);
end;

docName = 'openminds';

switch lower(dependency_type),
	case '',
		dependency_name = '';
		docName = 'openminds';
	case 'subject',
		dependency_name = 'subject_id';
		docName = 'openminds_subject';
	case 'element',
		dependency_name = 'element_id';
		docName = ['openminds_element'];
	case 'stimulus',
		dependency_name = 'stimulus_element_id';
		docName = ['openminds_stimulus'];
	otherwise,
		error(['Unknown DEPENDENCY_TYPE ' dependency_type '.']);
end;

d = {};

for i=1:numel(s),
	openminds_struct = rmfield(s(i),'complete');
	ndi_id_here = openminds_struct.ndi_id;
	openminds_struct = rmfield(openminds_struct,'ndi_id');
	d{i} = ndi.document(docName,'base.id',ndi_id_here,...
		'base.session_id',session_id,...
		'openminds',openminds_struct,varargin{:});
	fn = fieldnames(openminds_struct.fields);
	added_dependency = 0;
	for j=1:numel(fn),
		g = getfield(openminds_struct.fields,fn{j});
		if iscell(g),
			for k=1:numel(g),
				if ischar(g{k}),
					if startsWith(g{k},'ndi://'),
						id_here = g{k}(7:end);
						d{i} = add_dependency_value_n(d{i},...
							'openminds',id_here,...
							'ErrorIfNotFound',0);
						added_dependency = 1;
					end;
				end;
			end;
		end;
	end;
	if ~added_dependency,
		d{i} = set_dependency_value(d{i},'openminds','','ErrorIfNotFound',0);
	end;
	if ~isempty(dependency_name),
		d{i} = d{i}.set_dependency_value(dependency_name,dependency_value);
	end;
end;


