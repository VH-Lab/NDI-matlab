function [kind, block] = kindOf(doc)
%KINDOF What a built V2 document is: its class, or an entity's type.
%
%   [KIND, BLOCK] = ndi.v2.kindOf(DOC) is DOC's class name and the block
%   holding its own fields ('session', 'session') -- except for an `entity`
%   (did2.build's documents), where KIND is its `type` ('session',
%   'dataset', 'organism', ...) and BLOCK is 'entity'. So code asking "is
%   this the dataset?" works on built and migrated documents alike.

arguments
    doc
end

kind = char(doc.document_class.class_name);
block = kind;
if strcmp(kind, 'entity') && isfield(doc, 'entity') && isfield(doc.entity, 'type')
    % NDI's handle for the type, read by node (Jess Haley 2026-10-22
    % [vocabulary nodes] L2), so `kind` is 'dataset' whether the stored name
    % is 'dataset' or the ontology label
    kind = char(ndi.v2.vocabHandle('entity_type', doc.entity.type));
end
end
