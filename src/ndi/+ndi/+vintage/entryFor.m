function [entry, vintage] = entryFor(target)
%ENTRYFOR The map entry for a concept name, a class name, or a document.
%
%   [ENTRY, VINTAGE] = ndi.vintage.entryFor(TARGET)
%
%   TARGET may be a concept/class name (char) or an ndi.document /
%   did.document. ENTRY is the ndi.vintage.map row, or [] when the target is
%   not a class V_eta renamed. VINTAGE is 'v1', 'V_eta' or '' -- and the
%   EMPTY case is the one to read carefully: it means "this map says nothing
%   about that", NOT "this is v1".
%
%   Most of NDI's document classes are unrenamed (`session`, `subject`,
%   `daqreader`, every ingested class), so an empty ENTRY is the ordinary
%   case and every caller must treat it as "behave exactly as before".
%
%   See also: ndi.vintage.map.

entry = [];
vintage = '';

if isa(target, 'ndi.document') || isa(target, 'did.document')
    props = target.document_properties;
    if ~isfield(props, 'document_class') || ~isstruct(props.document_class) ...
            || ~isfield(props.document_class, 'class_name')
        return;
    end
    name = props.document_class.class_name;
elseif ischar(target) || isstring(target)
    name = char(target);
else
    error('NDI:vintage:badTarget', ...
        ['ndi.vintage.entryFor expects a class name or a document ' ...
         '(got "%s").'], class(target));
end

m = ndi.vintage.map();
for i = 1:numel(m)
    if strcmp(name, m(i).v1_class)
        entry = m(i);
        vintage = 'v1';
        return;
    end
    if strcmp(name, m(i).eta_class)
        entry = m(i);
        vintage = 'V_eta';
        return;
    end
end
end
