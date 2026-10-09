function values = edge_n(ndi_document_obj, v1_edge_name, options)
%EDGE_N Read a NUMBERED dependency family by its v1 base name, either vintage.
%
%   VALUES = ndi.vintage.edge_n(NDI_DOCUMENT_OBJ, V1_EDGE_NAME)
%   VALUES = ndi.vintage.edge_n(..., 'ErrorIfNotFound', 0)
%
%   The v1/V_eta spellings differ by BASE NAME, and the numbering suffix is
%   the same on both sides -- v1 `daqmetadatareader_id_1..N` becomes V_eta
%   `acquisition_metadata_reader_1..N`. So the map stores base names and
%   `dependency_value_n` does the expansion, exactly as it did before.
%
%   The map's entries for the numbered families are the base names WITHOUT
%   the `_#` the schema used to write (`acquisition_metadata_reader_#`); `#`
%   was the schema's notation for the family, not part of any stored key.
%   did-schema T15 later replaced numbered families with ONE REPEATED name
%   (`epoch_parameter_reader_id` x N); both forms are read here.
%
%   See also: ndi.vintage.edge, ndi.vintage.edgeName, ndi.vintage.map.

arguments
    ndi_document_obj
    v1_edge_name (1,:) char
    options.ErrorIfNotFound (1,1) logical = 0
end

name = ndi.vintage.edgeName(ndi_document_obj, v1_edge_name);

% A REPEATED NAME IS A FAMILY TOO. did-schema T15 stores a family as one
% name repeated (`clock_alignment_configuration_id` N times) rather than
% numbered (`..._1`, `..._2`). dependency_value_n reads only the first
% entry of an unnumbered name, so the repeated form is collected here, in
% stored order.
props = ndi_document_obj.document_properties;
if isfield(props, 'depends_on') && isstruct(props.depends_on) ...
        && isfield(props.depends_on, 'name')
    hits = find(strcmp(name, {props.depends_on.name}));
    if numel(hits) > 1
        values = {};
        for i = 1:numel(hits)
            v = ndi.document.i_readDependencyTarget(props.depends_on(hits(i)));
            if ~isempty(v)
                values{end+1} = v; %#ok<AGROW>
            end
        end
        if isempty(values) && options.ErrorIfNotFound
            error(['Dependency name ' name ' not found.']);
        end
        return;
    end
end

values = ndi_document_obj.dependency_value_n(name, ...
    'ErrorIfNotFound', options.ErrorIfNotFound);
end
