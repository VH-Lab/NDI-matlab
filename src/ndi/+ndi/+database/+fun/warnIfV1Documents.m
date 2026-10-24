function n = warnIfV1Documents(db, what, location)
%WARNIFV1DOCUMENTS Warn once when an opened session or dataset holds v1 documents.
%
%   N = ndi.database.fun.warnIfV1Documents(DB, WHAT, LOCATION) counts the
%   v1 documents in the ndi.database DB (ndi.database.fun.v1DocumentCount)
%   and, if there are any, issues ONE warning with the identifier
%   'NDI:V2:v1DocumentsPresent' saying how many there are, that they are
%   read as stored, and that a migration or a V2 import makes V2 shapes.
%   WHAT ('session' or 'dataset') and LOCATION (its folder) name what was
%   opened. N is the count (NaN when it was not measured).
%
%   ndi.session.dir calls this when it opens an existing database, and
%   ndi.dataset.dir once for the dataset (the session opens it makes on the
%   way are silenced, so one open gives one warning).
%
%   Decided by Jess Haley, 2026-10-23 [warn on v1 open]: opening a dataset
%   that still holds unmigrated v1 documents warns once. Reading is
%   unchanged: a v1 document is read as stored ([v1 read as stored];
%   ndi.database.internal.applyReadNormalization).
%
%   If the count itself fails, the open goes on and the failure is reported
%   as the warning 'NDI:V2:v1DocumentsNotCounted' instead; it is never
%   reported as "no v1 documents".
%
%   To silence it: warning('off', 'NDI:V2:v1DocumentsPresent').
%
%   See also: ndi.database.fun.v1DocumentCount, ndi.migrate.local.

    arguments
        db (1,1) ndi.database
        what (1,:) char
        location (1,:) char
    end

    try
        [n, how] = ndi.database.fun.v1DocumentCount(db);
    catch err
        n = NaN;
        warning('NDI:V2:v1DocumentsNotCounted', ...
            'Could not count the v1 documents of the %s at %s: %s', ...
            what, location, err.message);
        return;
    end

    if ~isnan(n) && n > 0
        warning('NDI:V2:v1DocumentsPresent', ...
            ['The %s at %s holds %d unmigrated v1 document(s) (%s). They are ' ...
             'read as stored, in their v1 shapes; only a migration ' ...
             '(ndi.migrate.local) or a V2 import writes V2 (V_eta) shapes.'], ...
            what, location, n, how);
    end
end
