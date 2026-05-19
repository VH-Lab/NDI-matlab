function ndiDocumentObj = applyReadNormalization(rawDoc)
%APPLYREADNORMALIZATION Normalise a stored document body to V_delta on read.
%
%   NDIDOCUMENTOBJ = ndi.database.internal.applyReadNormalization(RAWDOC)
%   wraps a body read from a concrete ndi.database backend in an
%   ndi.document. When the env var NDI_DID2_NORMALIZE_ON_READ is set to
%   '1', RAWDOC is first routed through did2.convert.v1_to_v2 so v1
%   bodies are returned as V_delta-shaped documents. V_delta bodies
%   short-circuit the converter's idempotency check, so re-reads of
%   already-V_delta documents stay cheap.
%
%   The env-var gate is OFF by default so this PR can land ahead of the
%   companion work that the issue body lists as dependencies:
%     - "Issue 1": NDI schemas converted to V_delta (every blank doc
%       under src/ndi/ndi_common/database_documents/ is still v1, and
%       ndi.document.readblankdefinition reads from there).
%     - #779: in-memory compat shim that injects legacy aliases on
%       ndi.document read, so existing callers (e.g.,
%       ndi.database.fun.ndi_document2ndi_object,
%       ndi.daq.metadatareader) keep finding v1 field names like
%       ndi_daqmetadatareader_class after V_delta normalisation
%       renames them to reader_class.
%   With the gate OFF the wiring + tests in this file are dormant; flip
%   to ON via setenv('NDI_DID2_NORMALIZE_ON_READ','1') once #779 / issue
%   1 ship to activate normalisation across every ndi.database backend.
%
%   Concrete ndi.database subclasses call this helper from their
%   do_read / do_search implementations so the abstract ndi.database
%   API stays byte-identical regardless of the gate state: callers
%   above the abstraction (session, dataset, queries) only ever see
%   ndi.document objects.
%
%   RAWDOC may be:
%       - a struct                (the body itself),
%       - a did.document          (its document_properties is used),
%       - a did2.document         (its toStruct() is used),
%       - an ndi.document         (passed through unchanged),
%       - empty []                (returns []).
%
%   Errors:
%       NDI:database:normalizeBadInput  - RAWDOC is not a recognised
%                                         document/body type.
%       NDI:database:normalizeFailed    - the gate is ON and
%                                         did2.convert.v1_to_v2
%                                         quarantined the body so no
%                                         migrated document was produced.
%
%   See also: did2.convert.v1_to_v2, ndi.database,
%             ndi.database.implementations.database.didsqlite,
%             ndi.database.implementations.database.matlabdumbjsondb2.

    if isempty(rawDoc)
        ndiDocumentObj = [];
        return;
    end

    if isa(rawDoc, 'did.document')
        body = rawDoc.document_properties;
    elseif isa(rawDoc, 'did2.document')
        body = rawDoc.toStruct();
    elseif isa(rawDoc, 'ndi.document')
        ndiDocumentObj = rawDoc;
        return;
    elseif isstruct(rawDoc) && isscalar(rawDoc)
        body = rawDoc;
    else
        error('NDI:database:normalizeBadInput', ...
            ['ndi.database.internal.applyReadNormalization expects a ' ...
             'struct, did.document, did2.document, or ndi.document ' ...
             '(got "%s").'], class(rawDoc));
    end

    if ~normalizationGateOn()
        % Gate OFF: preserve the pre-#776 behaviour (just wrap the
        % body) so the rest of the codebase keeps finding v1 field
        % names until issue 1 / #779 land.
        ndiDocumentObj = ndi.document(body);
        return;
    end

    % Validate=false on the read path: the body was validated when it
    % was written, and re-validating every read for every doc burns
    % time on production workloads. The migrate command and the write
    % path remain responsible for validation.
    result = did2.convert.v1_to_v2(body, 'Validate', false);

    if isempty(result.migrated)
        if ~isempty(result.quarantine)
            reason = result.quarantine(1).reason;
            className = result.quarantine(1).class_name;
        else
            reason = '<no quarantine reason recorded>';
            className = '<unknown>';
        end
        error('NDI:database:normalizeFailed', ...
            ['did2.convert.v1_to_v2 failed to normalise a document ' ...
             'on read (class=%s): %s'], className, reason);
    end

    ndiDocumentObj = ndi.document(result.migrated{1}.toStruct());
end

function tf = normalizationGateOn()
% Read NDI_DID2_NORMALIZE_ON_READ and treat '1', 'true', 'yes', 'on' as
% ON (case-insensitive). Anything else (including unset) is OFF.
raw = getenv('NDI_DID2_NORMALIZE_ON_READ');
if isempty(raw)
    tf = false;
    return;
end
tf = any(strcmpi(strtrim(raw), {'1', 'true', 'yes', 'on'}));
end
