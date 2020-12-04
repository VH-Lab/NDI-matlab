function docs = schemastructure2docstructure(schema)
% schemastructure2docstructure - return documentation information from an ndi document schema
%
% DOCS = SCHEMASTRUCTURE2DOCSTRUCTURE(SCHEMA)
%
% Given an NDI schema structure (json-schema.org/draft/2019-09/schema#)
% this function returns documentation information for all properties.
% 
% This returns a structure array with fields:
%   - property
%   - doc_default_value
%   - doc_data_type
%   - doc_description 
%
%

docstring = {'doc_default_value', 'doc_data_type','doc_description'};

docs = vlt.data.emptystruct('property',docstring{:});

fn = fieldnames(schema);

property_match = find(strcmpi('properties',fn));

if ~isempty(property_match),
	v = getfield(schema,'properties');
	if ~isstruct(v),
		error(['Expected ''properties'' field to be a struct.']);
	end;
	fns = fieldnames(v);

	for i=1:numel(fns),
		fns{i}
		v_i = getfield(v,fns{i});
		p_here = vlt.data.emptystruct('property',docstring{:});
		if isstruct(v_i),
			p_here(1).property = fns{i};
			fnss = fieldnames(v_i);
			subproperty_match = find(strcmpi('properties',fnss));
			subitem_match = find(strcmpi('items',fnss));
			for j=1:numel(docstring),
				ds = find(strcmpi(docstring{j},fnss));
				if ~isempty(ds),
					p_here(1)=setfield(p_here(1),docstring{j},...
						getfield(v_i,docstring{j}));
				end;
			end;
		else,
			subproperty_match = [];
			subitem_match = [];
		end;

		if ~isempty(p_here), % we have something to add
			docs(end+1) = p_here;
		end;

		% it remains possible that there is more to explore here
		% such as properties.thing.properties
		%  or properties.thing.items
		
		if ~isempty(subproperty_match) | ~isempty(subitem_match),
			disp(['Exploring deeper:']);
			v_i,
			pmore = ndi.database.fun.schemastructure2docstructure(v_i);
			for j=1:numel(pmore),
				pmore(j).property = [fns{i} '.' pmore(j).property];
				docs(end+1) = pmore(j);
			end;
		end;
	end;
end;
