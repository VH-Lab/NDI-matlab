function ndiDocumentObj = applyReadNormalization(rawDoc)
%APPLYREADNORMALIZATION Normalise a stored document body to V_delta on read.
%
%   NDIDOCUMENTOBJ = ndi.database.internal.applyReadNormalization(RAWDOC)
%   wraps a body read from a concrete ndi.database backend in an
%   ndi.document. RAWDOC is routed through did2.convert.v1_to_v2 so v1
%   bodies are returned as V_delta-shaped documents. V_delta bodies
%   short-circuit the converter's idempotency check, so re-reads of
%   already-V_delta documents stay cheap.
%
%   The converter is called with RenameClassNames=false: NDI's on-disk
%   schemas still spell classnames and property-block keys in
%   camelCase (e.g., demoNDI), and the legacy v1 validator compares
%   class_name strings exactly. Skipping the identifier snake_case
%   sweep keeps legacy docs schema-compatible on read while still
%   applying the V_delta shape transformations (schema_version
%   stamping, base reconciliation, app block renames, depends_on
%   rewrite).
%
%   The in-memory ndi.document then carries the did_v1 legacy alias
%   paths injected by ndi.compat.augmentRead (issue #779) plus
%   canonical `depends_on.document_id` entries via
%   ndi.compat.normalizeDependsOn (issue #801). Callers that still
%   read legacy field names (e.g.,
%   ndi.database.fun.ndi_document2ndi_object,
%   ndi.daq.metadatareader, customer code reading
%   document_properties.probe_location.ontology_name) keep working
%   even though storage normalised to V_delta. The write-side mirror
%   lives in ndi.compat.reconcileWrite (issue #780); query-side path
%   translation lives in ndi.compat.translateQueryPaths (issue #781).
%
%   Concrete ndi.database subclasses call this helper from their
%   do_read / do_search implementations so the abstract ndi.database
%   API stays byte-identical: callers above the abstraction (session,
%   dataset, queries) only ever see ndi.document objects.
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
%       NDI:database:normalizeFailed    - did2.convert.v1_to_v2
%                                         quarantined the body so no
%                                         migrated document was produced.
%
%   See also: did2.convert.v1_to_v2, ndi.compat.augmentRead,
%             ndi.compat.normalizeDependsOn,
%             ndi.compat.reconcileWrite, ndi.compat.translateQueryPaths,
%             ndi.database,
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

    % Validate=false on the read path: the body was validated when it
    % was written, and re-validating every read for every doc burns
    % time on production workloads. The migrate command and the write
    % path remain responsible for validation.
    %
    % RenameClassNames=false preserves legacy (camelCase) identifiers
    % on the body. NDI on-disk schemas (e.g., demoNDI, demoNDIMock)
    % still spell classnames and block keys in camelCase, and the
    % legacy v1 validator (did.database/validate_doc_vs_schema) compares
    % body.document_class.class_name against schema.classname by exact
    % string. Snake-casing here would trip ValidationClassname on every
    % read of a legacy doc. Schema_version stamping, base reconciliation,
    % app block renames, and depends_on rewrites still run — those are
    % the V_delta shape transformations the read path actually needs.
    % THE TARGET IS NAMED HERE, not inherited. This call passed no
    % TargetVersion and so took did2.convert.v1_to_v2's own default -- a
    % default set for the converter's callers, not for this read path. The
    % version every document NDI reads is normalised to was therefore decided
    % in another repository, by a parameter nobody here mentions.
    %
    % It is still 'V_delta', deliberately and visibly: flipping the read path
    % to V_eta would run the per-class migrators on every read while the NINE
    % BATCH POST-PASSES and the NDI second pass -- epochMint, resolveSessionAnchors,
    % recordingAttribution and the rest -- CANNOT run per document, because they
    % need the whole set. That would produce half-migrated documents that look
    % migrated. Changing this constant is a real decision and now has to be made
    % on purpose.
    %
    % V_eta documents are unaffected either way as of 2026-08-14: they rank
    % BEYOND this target, and isAlreadyTarget now compares rank rather than
    % string equality, so they pass through untouched instead of being pushed
    % back through migrators aimed at a version they have already passed.
    % ALREADY AT THE TARGET (every V2 document): with validation off, the
    % full pass below reduces to exactly did2.convert.ensureClassBlocks (the
    % base-field rename does nothing at this target, and wrapping in a
    % did2.document and unwrapping is the identity), so apply that alone
    % instead of the per-document batch machinery: 1.2 s of 2.4 s listing
    % the 10,536 Haley V2 subjects. DID-matlab's testV1ToV2Audits pins that
    % the two give the same document; only when that DID-matlab is present
    % (#218), otherwise the full pass runs as before.
    if hasReadShortcut() && did2.convert.isAlreadyTarget(body, READ_TARGET_VERSION)
        ndiDocumentObj = ndi.document(did2.convert.ensureClassBlocks(body, []));
        return;
    end

    % The report-only census (silentLoss, fileList, timeReferenceFamilies)
    % is skipped: this read discards it, and on one-document reads it cost
    % more than the conversion (23.5 s of 51 s profiled over the 10,536
    % Haley V2 subjects). Only when DID-matlab's v1_to_v2 has the option
    % (DID-matlab #218); an older one runs it as before.
    auditArgs = {};
    if v1ToV2HasAudits()
        auditArgs = {'Audits', false};
    end
    result = did2.convert.v1_to_v2(body, 'Validate', false, ...
        'RenameClassNames', false, 'TargetVersion', READ_TARGET_VERSION, auditArgs{:});

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

function v = READ_TARGET_VERSION()
%READ_TARGET_VERSION The schema version NDI normalises stored bodies TO on read.
%   ONE definition, named, so "what version does NDI read at" is answerable by
%   grep instead of by tracing an unpassed argument into another repository's
%   default. See the call site for why it is still V_delta and what changing it
%   would require.
v = 'V_delta';
end

function tf = v1ToV2HasAudits()
%V1TOV2HASAUDITS True when did2.convert.v1_to_v2 takes the 'Audits' option.
%   Read once from its source and remembered; drop this test once every
%   supported DID-matlab has the option (DID-matlab #218).
persistent has
if isempty(has)
    has = false;
    try
        f = which('did2.convert.v1_to_v2');
        has = ~isempty(f) && contains(fileread(f), 'options.Audits');
    catch
    end
end
tf = has;
end

function tf = hasReadShortcut()
%HASREADSHORTCUT True when DID-matlab has did2.convert.isAlreadyTarget and
%   ensureClassBlocks as public functions (DID-matlab #218). Remembered;
%   drop this test once every supported DID-matlab has them.
persistent has
if isempty(has)
    has = ~isempty(which('did2.convert.isAlreadyTarget')) && ...
        ~isempty(which('did2.convert.ensureClassBlocks'));
end
tf = has;
end
