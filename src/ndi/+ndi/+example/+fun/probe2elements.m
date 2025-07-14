function [ed,e] = probe2elements(probe, options)
% PROBE2ELEMENTS - retrieve the elements derived directly from a probe
% 
% [ED,E] = PROBE2ELEMENTS(PROBE, ...)
% 
% Retrieves element documents and the corresponding ndi.element objects
% that are derived from the ndi.probe object PROBE.
%
% One can provide additional arguments as name/value pairs that modify the
% default behavior:
% |-------------------------|------------------------------------------|
% | Parameter (default)     | Description                              |
% |-------------------------|------------------------------------------|
% | type ('')               | If not empty, restrict to this element   |
% |                         |   type (e.g., 'spikes')                  |
% | name ('')               | If not empty, restrict to element name   |
% | reference (NaN)         | If not NaN, restrict to reference        |
% |-------------------------|------------------------------------------|
%

arguments
    probe (1,1) ndi.probe
    options.type (1,:) char = ''
    options.name (1,:) char = ''
    options.reference (1,1) double = NaN
end

q = ndi.query('','depends_on','underlying_element_id',probe.id());

if ~isempty(options.type)
    q = q & ndi.query('element.type','exact_string',options.type);
end

if ~isempty(options.name)
    q = q & ndi.query('element.type','exact_string',options.name);
end

if ~isnan(options.reference)
    q = q & ndi.query('element.reference','exact_number',options.reference);
end

ed = probe.session.database_search(q);
e = {};

if nargout>1
    for i=1:numel(ed)
        e{i} = ndi.database.fun.ndi_document2ndi_object(ed{i},probe.session);
    end
end

