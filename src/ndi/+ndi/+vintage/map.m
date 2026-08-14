function entries = map()
%MAP The one declaration of how a V_eta document says what a v1 document said.
%
%   ENTRIES = ndi.vintage.map() returns a struct array, one entry per NDI
%   OBJECT CONCEPT whose document class V_eta renamed. Everything else in
%   this package reads it; nothing else in NDI hard-codes a V_eta class or
%   edge name.
%
%   WHY A MAP AND NOT A REWRITE
%   ---------------------------
%   NDI's object layer identifies its documents by v1 class name
%   (`ndi.query('','isa','daqsystem')`), constructs them from a field named
%   after that class (`ndi_daqsystem_class`), and reads their edges by v1
%   edge name (`daqreader_id`). V_eta renamed all three. So after migration
%   every one of those lookups matched nothing and returned `{}` -- no
%   error, just an empty session.
%
%   The fix is NOT to port the object layer off v1, and that distinction is
%   the whole design. NDI still WRITES v1: `ndi.session.dir` on a fresh
%   directory creates a legacy database (see
%   ndi.database.fun.databasehierarchyinit -- only the first entry can
%   create one, and it is `didsqlite`). An object layer that spoke only
%   V_eta could not read a session NDI had just made. So the object layer
%   is defined over BOTH vintages, from one declaration, and a document
%   answers for itself which one it is.
%
%   ENTRY FIELDS
%   ------------
%     concept        the v1 class name, and the key callers use
%     v1_class       the class a v1 document declares
%     eta_class      the class a V_eta document declares
%     object_field   v1: the block field holding the MATLAB class to
%                    construct (the "object-reconstruction key")
%     object_edge    V_eta: the edge to a `software` entity whose `name`
%                    holds that same MATLAB class name. The migrators fold
%                    the class string into an entity -- see
%                    DID-matlab +migrators_j/private/jSoftware.m, called
%                    with the implementation class as NAME.
%     edges          N-by-2 cellstr, {v1_edge, eta_edge}. Base names: a
%                    numbered family (`daqmetadatareader_id_1`, ...) is
%                    stored by its base and expanded by ndi.vintage.edge_n.
%     fields         N-by-2 cellstr, {v1_field, eta_field}, within the
%                    document's own block.
%
%   WHAT IS DELIBERATELY ABSENT
%   ---------------------------
%   `element` and `pyraview` are NOT here, and cannot be added by writing a
%   row. V_eta DECOMPOSES them -- one `element` document becomes `subject` +
%   `term_assertion` + `directed_relation` + `sampled_body` +
%   `session_relative_reference`, and the migrator's own header states the
%   intent: "Strict J retires the recording-side `element` class (J:214,
%   D2): any identifiable thing ... is a `subject`". Reassembling an
%   `ndi.element` from five documents would rebuild a class V_eta
%   deliberately retired. Whether `ndi.element` survives V_eta is a
%   modelling decision for the team, not something this map can express.
%
%   A CORRECTION KEPT IN PLACE, because the mistake is instructive. This
%   note used to say `daqreader` "needs nothing -- V_eta keeps the class
%   name AND keeps `ndi_daqreader_class` as a field". Both halves are true
%   about the SCHEMA SET and neither is true about a MIGRATED DOCUMENT:
%   `schemas/V_eta/stable/daqreader.json` is the v1 TOMBSTONE, and what the
%   migrator emits is `acquisition_reader`
%   (+migrators_j/daqreader.m:159, "did_v1 daqreader folds to an
%   `acquisition_reader` + a `software` entity"). Reasoning from "the name
%   still exists in V_eta" instead of "what does the migrator emit" cost a
%   CI run, and it failed four levels deep -- after the acquisition_system
%   was found, its class resolved and its reader_id followed -- because
%   every earlier step was right.
%
%   `session` and `subject` are absent because V_eta renames neither class.
%
%   See also: ndi.vintage.isaQuery, ndi.vintage.objectClass,
%             ndi.vintage.edge, ndi.vintage.edge_n, ndi.vintage.field,
%             ndi.database.fun.ndi_document2ndi_object.

persistent cached
if ~isempty(cached)
    entries = cached;
    return;
end

% BUILT BY FIELD ASSIGNMENT, NOT BY struct(). `struct('fields', {cell(0,2)})`
% does NOT make a scalar struct with an empty cell in it -- struct() unwraps a
% cell argument and produces a struct ARRAY of that cell's size, so an empty
% cell yields a 0x2 EMPTY struct array and the entry silently disappears.
% Assigning field by field has no such rule.
e = struct('concept', {}, 'v1_class', {}, 'eta_class', {}, ...
    'object_field', {}, 'object_edge', {}, 'object_assertion', {}, ...
    'isa_bridges', {}, 'edges', {}, 'fields', {});
k = 0;

% ---- daqsystem -> acquisition_system ---------------------------------
% Edge names from schemas/V_eta/stable/acquisition_system.json
%   deps = software_id, reader_id, epoch_file_pattern_id,
%          acquisition_metadata_reader_#
% and from +migrators_j/daqsystem.m's own "THE EDGE MAPPING" table.
% NOTE the two software edges are NOT interchangeable, and the migrator
% says which is which: `software_id` is "the rig's OWN implementation --
% what this document IS"; `reader_id` is "a DIFFERENT component's
% identity, from v1 daqreader_id". Taking `reader_id` as the object key
% would construct the reader's class instead of the system's.
k = k + 1;
e(k).concept      = 'daqsystem';
e(k).v1_class     = 'daqsystem';
e(k).eta_class    = 'acquisition_system';
e(k).object_field = 'ndi_daqsystem_class';
e(k).object_edge  = 'software_id';
e(k).object_assertion = '';
e(k).isa_bridges  = true;
e(k).edges        = {'daqreader_id',         'reader_id'; ...
                     'filenavigator_id',     'epoch_file_pattern_id'; ...
                     'daqmetadatareader_id', 'acquisition_metadata_reader'};
e(k).fields       = cell(0,2);

% ---- filenavigator -> epoch_file_pattern -----------------------------
% Field mapping quoted from +migrators_j/filenavigator.m:34-36.
k = k + 1;
e(k).concept      = 'filenavigator';
e(k).v1_class     = 'filenavigator';
e(k).eta_class    = 'epoch_file_pattern';
e(k).object_field = 'ndi_filenavigator_class';
e(k).object_edge  = 'software_id';
e(k).object_assertion = '';
e(k).isa_bridges  = true;
e(k).edges        = cell(0,2);
e(k).fields       = {'fileparameters',               'data_file_pattern'; ...
                     'epochprobemap_fileparameters', 'epoch_map_pattern'; ...
                     'epochprobemap_class',          'epoch_map_format'};

% ---- daqmetadatareader -> acquisition_metadata_reader ----------------
k = k + 1;
e(k).concept      = 'daqmetadatareader';
e(k).v1_class     = 'daqmetadatareader';
e(k).eta_class    = 'acquisition_metadata_reader';
e(k).object_field = 'ndi_daqmetadatareader_class';
e(k).object_edge  = 'software_id';
e(k).object_assertion = '';
e(k).isa_bridges  = true;
e(k).edges        = cell(0,2);
e(k).fields       = {'tab_separated_file_parameter', 'metadata_file_pattern'};

% ---- daqreader -> acquisition_reader ---------------------------------
% `daqreader_ndr` folds into this too (the reader subtype was encoded in
% the class name and is already discriminated by the class string).
% v1 `daqreader.reader_string` keeps its name on acquisition_reader, so
% there is no field row -- only the object key moves, from the field to
% the software entity.
k = k + 1;
e(k).concept      = 'daqreader';
e(k).v1_class     = 'daqreader';
e(k).eta_class    = 'acquisition_reader';
e(k).object_field = 'ndi_daqreader_class';
e(k).object_edge  = 'software_id';
e(k).object_assertion = '';
e(k).isa_bridges  = true;
e(k).edges        = cell(0,2);
% BOTH v1 READER CLASSES LAND HERE, so both their field spellings are
% listed on this one row. `daqreader.reader_string` keeps its name;
% `daqreader_ndr.ndr_reader_string` becomes `reader_string` too
% (+migrators_j/daqreader_ndr.m: "ndr_reader_string ->
% daqreader.reader_string"). A v1 `daqreader_ndr` document matches no
% entry at all -- it is not any row's v1_class -- so ndi.vintage.field
% falls through to reading the block named after its own class, which is
% exactly the untouched v1 behaviour.
e(k).fields       = {'ndr_reader_string', 'reader_string'};

% ---- syncgraph -> clock_alignment_policy -----------------------------
k = k + 1;
e(k).concept      = 'syncgraph';
e(k).v1_class     = 'syncgraph';
e(k).eta_class    = 'clock_alignment_policy';
e(k).object_field = 'ndi_syncgraph_class';
e(k).object_edge  = 'software_id';
e(k).object_assertion = '';
e(k).isa_bridges  = true;
e(k).edges        = {'syncrule_id', 'clock_alignment_configuration'};
e(k).fields       = cell(0,2);

% ---- syncrule -> clock_alignment_configuration -----------------------
% `parameters` is NOT a field rename: V_eta exploded the bag into typed
% fields and moved the device pair into two `acquisition_channels`
% documents. ndi.vintage.syncruleParameters does that reassembly; there is
% no one-to-one row to put here.
k = k + 1;
e(k).concept      = 'syncrule';
e(k).v1_class     = 'syncrule';
e(k).eta_class    = 'clock_alignment_configuration';
e(k).object_field = 'ndi_syncrule_class';
e(k).object_edge  = 'software_id';
e(k).object_assertion = '';
e(k).isa_bridges  = true;
e(k).edges        = {'acquisition_channels', 'acquisition_channels'};
e(k).fields       = cell(0,2);

% ---- element -> subject (+ satellites) -------------------------------
% THE ONE ENTRY WHOSE `isa_bridges` IS FALSE, and the reason is the whole
% difference between this row and the six above. Those six renamed a class
% to a class NDI uses for nothing else, so `isa acquisition_system` finds
% daq systems and only daq systems. `element` became `subject` -- and NOT
% every subject was an element. In PRED, migrating 2 elements plus 1
% animal yields THREE subject documents, so bridging `isa element` onto
% `isa subject` would return the animal as a probe.
%
% What separates them is an inbound `term_assertion` carrying
% `ndi.vintage.elementLabel('class')`. That is a second document, and a
% did.query evaluates against one document at a time, so this cannot be
% expressed as an `isa` query at all -- ndi.vintage.elementSubjectDocs
% does it in two steps instead. `isa_bridges = false` is what stops
% isaQuery from trying.
%
% The row still earns its place: ndi.vintage.objectClass uses
% `object_assertion` to recover the MATLAB class from that same
% assertion, so `ndi_document2ndi_object` works on a migrated element the
% way it works on everything else.
k = k + 1;
e(k).concept      = 'element';
e(k).v1_class     = 'element';
e(k).eta_class    = 'subject';
e(k).object_field = 'ndi_element_class';
e(k).object_edge  = '';
e(k).object_assertion = 'ndi element class';   % ndi.vintage.elementLabel('class')
e(k).isa_bridges  = false;
e(k).edges        = cell(0,2);
e(k).fields       = cell(0,2);

cached = e;
entries = e;
end
