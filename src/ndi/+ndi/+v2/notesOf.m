function s = notesOf(block)
%NDI.V2.NOTESOF The free text of a V2 `entity` or `data_body` block, as char.
%
%   S = ndi.v2.notesOf(BLOCK) is BLOCK.notes, else BLOCK.description, else ''.
%   did-schema did_v2_go_forward_class_audit.md [one free-text field: notes]
%   (Jess Haley, 2026-10-25) renames `entity.description` and
%   `data_body.description` to `notes`; readers read both until every
%   writer has moved.
%
%   See also ndi.v2.notesField.
s = '';
if ~isstruct(block) || ~isscalar(block)
    return;
end
for f = {'notes', 'description'}
    if isfield(block, f{1}) && ~isempty(block.(f{1})) ...
            && (ischar(block.(f{1})) || isstring(block.(f{1})))
        s = char(block.(f{1}));
        return;
    end
end
end
