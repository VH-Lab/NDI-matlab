function [n, how] = v1DocumentCount(db)
%V1DOCUMENTCOUNT How many documents in an NDI database are not V2 (V_eta) documents.
%
%   [N, HOW] = ndi.database.fun.v1DocumentCount(DB) returns the number N of
%   documents in the ndi.database DB that are stored as v1 documents, that
%   is, documents that ndi.database.internal.applyReadNormalization reads as
%   stored because they carry no V_eta stamp. HOW is a short description of
%   what was counted, for a message.
%
%   A V2 document is one whose document_class.schema_version is a V2 stamp,
%   did2.schema.v2Stamps ('did_v2', and 'V_eta' only until the writers stamp
%   'did_v2': Decided by Jess Haley, 2026-10-25 [document stamps], [V_eta
%   stamp not accepted]). Every other document is counted, including a v1
%   document ndi.migrate.local carried unchanged and stamped 'did_v1'.
%
%   How each backend is counted, without reading every document:
%
%     did2sqlite   one query, document_class.schema_version ~exact_string
%                  each V2 stamp; only the matching (v1) document ids are read.
%     didsqlite    the v1 backend. Its index leaves out document_class
%                  (did.implementations.doc2sql), so the stamp cannot be
%                  queried there; N is the number of documents in it, read
%                  as ids only. Every V2 writer (ndi.setup.V2, ndi.migrate)
%                  writes a did2sqlite database, not this one.
%     any other    not counted: N is NaN ("not measured"), never 0.
%
%   See also: ndi.database.fun.warnIfV1Documents,
%             ndi.database.internal.applyReadNormalization,
%             did2.convert.isAlreadyTarget.

    arguments
        db (1,1) ndi.database
    end

    if isa(db, 'ndi.database.implementations.database.did2sqlite')
        stamps = did2.schema.v2Stamps();
        q = did2.query('document_class.schema_version', '~exact_string', stamps{1});
        for k = 2:numel(stamps)
            q = and(q, did2.query('document_class.schema_version', '~exact_string', stamps{k}));
        end
        n = numel(db.db.searchIds(q));
        how = 'documents without a V2 stamp';
    elseif isa(db, 'ndi.database.implementations.database.didsqlite')
        n = numel(db.alldocids());
        how = 'documents in a v1 (did-sqlite) database';
    else
        n = NaN;
        how = sprintf('not measured for a %s database', class(db));
    end
end
