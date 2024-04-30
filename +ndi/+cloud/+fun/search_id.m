function [doc, i] = search_id(id,docs)
%SEARCH_ID Summary of this function goes here
%   Detailed explanation goes here
for i = 1:numel(docs)
    if contains(id,docs{i}.document_properties.base.id)
        doc = docs{i};
        break
    end
end
end

