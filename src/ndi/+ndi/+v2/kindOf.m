function [kind, block] = kindOf(doc)
%KINDOF What a built V2 document is: its class, or an entity's type.
%
%   [KIND, BLOCK] = ndi.v2.kindOf(DOC) is DOC's class name and the block
%   holding its own fields ('session', 'session') -- except for an `entity`
%   (a schema built on or after 2026-10-08), where
%   KIND is its `type` ('session', 'dataset', 'organism', ...) and BLOCK is
%   'entity'. So code asking "is this the dataset?" works on either schema.

kind = char(doc.document_class.class_name);
block = kind;
if strcmp(kind, 'entity') && isfield(doc, 'entity') && isfield(doc.entity, 'type')
    t = doc.entity.type;
    if isstruct(t), t = t.name; end
    kind = char(t);
end
end
