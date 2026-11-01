function s = notesOf(block)
%NDI.V2.NOTESOF The free text of a V2 `entity` or `data_body` block, as char.
%
%   S = ndi.v2.notesOf(BLOCK) is BLOCK.notes, else ''. did-schema
%   did_v2_go_forward_class_audit.md [one free-text field: notes] (Jess
%   Haley, 2026-10-25) renamed `description` on those blocks to `notes`; the
%   old name is not read.
s = '';
if ~isstruct(block) || ~isscalar(block)
    return;
end
if isfield(block, 'notes') && ~isempty(block.notes) ...
        && (ischar(block.notes) || isstring(block.notes))
    s = char(block.notes);
end
end
