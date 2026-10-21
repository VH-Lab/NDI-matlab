function id = subjectOf(ids, session, rowId)
%SUBJECTOF The id stage 2 gave the entity of SESSION's row ROWID; '' if none.

arguments
    ids table
    session {mustBeText}
    rowId {mustBeText}
end
id = '';
k = find(strcmp(ids.session, session) & strcmp(ids.row, rowId), 1);
if ~isempty(k)
    id = ids.id{k};
end
end
