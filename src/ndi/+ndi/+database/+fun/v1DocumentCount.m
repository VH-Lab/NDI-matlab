function [n, how] = v1DocumentCount(db)
%V1DOCUMENTCOUNT How many documents in an NDI database are not V2 (V_eta) documents.
%
%   [N, HOW] = ndi.database.fun.v1DocumentCount(DB) returns the number N of
%   documents in the ndi.database DB that are stored as v1 documents, that
%   is, documents that ndi.database.internal.applyReadNormalization reads as
%   stored because they carry no V_eta stamp. HOW is a short description of
%   what was counted, for a message.
%
%   A V_eta document is one whose document_class.schema_version is 'V_eta'
%   (did2.convert.v1_to_v2 stamps every document it emits, including a v1
%   document it carries unchanged). Every other document is counted.
%
%   How each backend is counted, without reading every document:
%
%     did2sqlite   one query, document_class.schema_version ~exact_string
%                  'V_eta'; only the matching (v1) documents are read.
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
        q = did2.query('document_class.schema_version', '~exact_string', 'V_eta');
        n = numel(db.db.searchIds(q));
        how = 'documents without a V_eta stamp';
    elseif isa(db, 'ndi.database.implementations.database.didsqlite')
        n = numel(db.alldocids());
        how = 'documents in a v1 (did-sqlite) database';
    else
        n = NaN;
        how = sprintf('not measured for a %s database', class(db));
    end
end
