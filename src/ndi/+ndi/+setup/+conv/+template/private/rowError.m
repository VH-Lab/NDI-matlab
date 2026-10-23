function r = rowError(r, where, err, throwErrors)
%ROWERROR A source item a stage could not import.
%
%   R = rowError(R, WHERE, ERR, THROWERRORS): on a normal run (THROWERRORS
%   false) the error is counted and listed in the stage report, and the
%   stage goes on with the next item, so one bad row does not stop an
%   import of thousands; the run folder's import_report.mat keeps the list.
%   In test mode (import_V2 'RunFolder', 'none'; THROWERRORS true) it is
%   thrown, as ndi:setup:conv:template:rowError with ERR as its cause, so a
%   test sees it instead of a green run with an error count nobody read.

arguments
    r (1,1) struct
    where {mustBeText}
    err (1,1) MException
    throwErrors (1,1) logical
end
if throwErrors
    e = MException('ndi:setup:conv:template:rowError', '%s stage, %s: %s', ...
        r.stage, char(where), err.message);
    e = addCause(e, err);
    throw(e);
end
r.errors = r.errors + 1;
r.errorList{end+1} = sprintf('%s: %s (%s)', char(where), err.message, err.identifier);
end
