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
%   `daqreader` is also absent, for the opposite reason: it needs nothing.
%   V_eta keeps the class name AND keeps `ndi_daqreader_class` as a field
%   (schemas/V_eta/stable/daqreader.json), so both the `isa` lookup and the
%   existing object-reconstruction path work unchanged. `daqreader_ndr`
%   folds INTO `daqreader`, and `isa daqreader` matched a `daqreader_ndr`
%   document before the migration too (it was a subclass), so that lookup
%   is unaffected in both directions.
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
    'object_field', {}, 'object_edge', {}, 'edges', {}, 'fields', {});
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
e(k).edges        = cell(0,2);
e(k).fields       = {'tab_separated_file_parameter', 'metadata_file_pattern'};

% ---- syncgraph -> clock_alignment_policy -----------------------------
k = k + 1;
e(k).concept      = 'syncgraph';
e(k).v1_class     = 'syncgraph';
e(k).eta_class    = 'clock_alignment_policy';
e(k).object_field = 'ndi_syncgraph_class';
e(k).object_edge  = 'software_id';
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
e(k).edges        = {'acquisition_channels', 'acquisition_channels'};
e(k).fields       = cell(0,2);

cached = e;
entries = e;
end
