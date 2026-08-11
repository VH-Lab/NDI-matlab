function [plan, report] = imagedEntitySubjects(v1Bodies, migratedStructs, options)
%IMAGEDENTITYSUBJECTS V_eta second pass: give a subject-less image the subject of
%   WHAT IT IS AN IMAGE OF, by following image -> ontologyTableRow -> subject
%   through the migrated-id graph.
%
%   [PLAN, REPORT] = ndi.migrate.internal.imagedEntitySubjects(V1BODIES,
%   MIGRATEDSTRUCTS) inspects every did_v1 image body that pass 1 left as a
%   PASSTHROUGH -- it is still an `image_stack` / `ontology_image` document in
%   MIGRATEDSTRUCTS, carrying its source id, because it had no subject -- works
%   out which already-existing subject the image depicts, and returns a PLAN:
%   for each image it could resolve, a COPY of the did_v1 body with a
%   `subject_id` dependency added. The caller re-folds each planned body through
%   did2.convert.v1_to_v2 at TargetVersion V_eta, where
%   did2.convert.migrators_j.image_stack's guard now passes and the
%   image_observation + sampled_body fold runs (see
%   ndi.migrate.local/resolveImagedEntitySubjects).
%
%   This function is PURE: it reads structs and returns structs. It calls no
%   converter, touches no database and needs no schema. That is what makes it
%   testable without a corpus.
%
%   REPORT states its denominators FIRST and unconditionally, and every refusal
%   has its own named bucket -- so a silent zero and a real zero are
%   distinguishable from the output alone.
%
%   STATUS: authored WITHOUT local MATLAB. MATLAB IS NOT INSTALLED in the
%   session that wrote this -- `command -v matlab octave octave-cli` finds
%   nothing -- so no line of this file, and no line of its unit tests
%   (tests/+ndi/+unittest/+migrate/TestImagedEntitySubjects.m), has ever been
%   run here. CI is the first execution. Nothing has been exercised against a
%   corpus.
%
%   ---------------------------------------------------------------------
%   THE TEAM DECISION THIS IMPLEMENTS
%   ---------------------------------------------------------------------
%   Taken in session, 2026-08-11: "Mint a subject for what the image is of. And
%   shouldn't there be an accompanying ontology_table_row that gives that
%   information?"
%
%   The answer to the second half is YES, and it is the whole mechanism: the
%   image names a table row, and the row is what says what the image depicts.
%
%   THE ANSWER TO THE FIRST HALF IS THAT THE SUBJECT IS ALREADY MINTED, AND
%   THIS PASS MUST NOT MINT A SECOND ONE. That is the single most important
%   sentence in this file. `did2.convert.resolveLawnPlateSubjects` -- wired at
%   ndi.migrate.local:736, landed the same day -- already implements the team's
%   earlier decision "each lawn can be a subject and a plate of lawns is another
%   subject", and it mints exactly the subject an E. coli image is of:
%
%       plate (a plate of lawns)  -> subject, local_identifier
%                                    `exp/<expID>/plate/<plateID>`
%       lawn  (a bacterial patch) -> subject, `exp/.../plate/.../patch/<patchID>`
%       lawn --member_of--> plate
%
%   and it says in its own "WHAT IT DOES NOT DO" section, verbatim:
%
%       "NO IMAGE SUBJECT. An image is not a subject; the image rows are read
%        as the JOIN TABLE they are and are left exactly as pass 1 emitted
%        them."
%
%   So the plate subject exists and the image is not attached to it. THAT GAP
%   IS THIS PASS. Minting a fresh subject here would put two subjects on one
%   plate, silently, in a way no gate would catch -- both would validate, both
%   would be referenced, and the corpus would simply contain a duplicate. This
%   pass therefore ATTACHES and never mints; where no subject exists it REFUSES
%   and COUNTS, and the count is the number that tells the team how much a mint
%   would be worth.
%
%   ---------------------------------------------------------------------
%   THE CHAIN, VERIFIED AGAINST WRITERS RATHER THAN TEMPLATES
%   ---------------------------------------------------------------------
%   The templates give the shape:
%
%     $ git show origin/main:src/ndi/ndi_common/database_documents/data/ontologyImage.json
%         "depends_on": [ { "name": "ontologyTableRow_id", "value": "" } ]
%     $ git show origin/main:src/ndi/ndi_common/database_documents/data/ontologyTableRow.json
%         "depends_on": [ { "name": "document_id", "value": "" } ]
%         "ontologyTableRow": { names, variableNames, ontologyNodes, data }
%
%   -- descriptive identity on the row, and what the image is OF one hop further
%   through the row's ONE generic `document_id` edge. Three documents, which is
%   why no single-document migrator can do it.
%
%   BUT THE POPULATION THAT ACTUALLY EXISTS IS NOT `ontologyImage`, AND THE HOP
%   THAT ACTUALLY FIRES IS NOT THAT EDGE. Three facts, each from a writer:
%
%   (a) NOTHING IN NDI WRITES AN `ontologyImage`. `imageDocMaker` is its only
%       maker and it has ZERO call sites:
%
%         $ grep -rn "imageDocMaker" --include=*.m .    # 927 .m files scanned
%         (only +setup/+NDIMaker/imageDocMaker.m itself)
%
%       THIS IS NOT EVIDENCE THAT NO SUCH DOCUMENT EXISTS. The corpora are a
%       sample of datasets and older lab scripts are not in this tree. The
%       population is INSPECTED AND COUNTED here, never assumed empty -- it is
%       simply not FOLDABLE (see "DELIBERATELY NOT DONE").
%
%   (b) THE IMAGES THAT EXIST ARE `imageStack`, AND THEIR EDGE IS `document_id`
%       NAMING AN `ontologyTableRow`. +setup/+conv/+haley/doImport.m's E. coli
%       session builds them at :789 :811 :827 (image / mask / closest-patch) and
%       sets the edge at :794 :814 :830 to `imageTable.image_id{p}`, the id of
%       the row built at :757. They are subject-less because that session
%       creates no subject at all: every `subject_id` occurrence in doImport.m
%       is at line 689 or earlier -- the C. elegans session -- while the E. coli
%       section runs 691-857. These are the 4,563 documents of the
%       `image_observation.subject_id` row of the empty-required-edge census.
%
%   (c) THE ROW'S `document_id` IS NOT POPULATED ON THAT PATH. Its only writer
%       is tableDocMaker.m:231/233, reachable only through the
%       `dependencyVariable` option, and NO converter in the tree passes it:
%
%         $ grep -rn "dependencyVariable" --include=*.m src/ | grep -v tableDocMaker.m
%         (3 hits, all PROSE inside +migrate/+internal/ontologyRowSubjects.m)
%
%       Route 1 below is built anyway: the option exists, the class declares the
%       edge, and a dataset that used it must not be silently mishandled.
%
%   ---------------------------------------------------------------------
%   THE TWO ROUTES
%   ---------------------------------------------------------------------
%   ROUTE 1 -- THE ROW'S `document_id` EDGE, resolved against the migrated set
%       and accepted ONLY when it lands on a `subject`. A row's edge pointing at
%       something that is not a subject is refused, not reinterpreted: this pass
%       does not get to decide that an arbitrary document is a physical thing.
%
%   ROUTE 2 -- THE PLATE HANDLE, session-scoped. This is the E. coli path and
%       the only one that fires on real data today. The image row carries the
%       depicted plate's identifier as an ordinary data cell:
%
%         doImport.m:717  plateVariables = {'expID','plateID', ... }
%         doImport.m:741  table2ontologyTableRowDocs(plateTable,{'plateID'},...)
%         doImport.m:747  imageVariables = {'plateID','imageID',
%                                           'lawnGrowthDuration','exposureTime'}
%         doImport.m:757  table2ontologyTableRowDocs(imageTable,
%                                           {'plateID','imageID'},...)
%
%       and `resolveLawnPlateSubjects` has already turned each plate row into a
%       subject whose `local_identifier` ENDS with `/plate/<plateID>`
%       (its plateHandle(), `sprintf('exp/%s/plate/%s', expId, plateId)`). So
%       the plate id read off the image row selects the plate subject directly,
%       and THE expID HOP IS NOT REDONE HERE -- re-deriving a join another pass
%       already performed is how two spellings of one identifier end up in one
%       dataset.
%
%       THE SUFFIX, NOT THE WHOLE HANDLE, IS THE KEY, and the distinction is
%       load-bearing: a PATCH handle is `exp/X/plate/Y/patch/Z`, which does NOT
%       end with `/plate/Y`, so a lawn subject can never be mistaken for the
%       plate it sits on.
%
%       THE SESSION SCOPE IS NOT DECORATION. +migrators_j/image_stack.m records
%       the collision it prevents: doImport.m:180 (behaviour) and :729 (E. coli)
%       both format plateID as num2str(...,'%.4i'), so both emit '0001','0002',
%       ... over the same range and ONLY `base.session_id` tells them apart.
%       Both sessions land in ONE ndi.dataset.dir. An unscoped join would
%       attach C. elegans plates to E. coli images, silently, at scale.
%
%       A STRING JOIN IS A WEAKER GUARANTEE THAN AN ID, so this route is
%       deliberately narrow, exactly as ontologyRowSubjects' route 3 is: the
%       match must be exact, session-scoped and UNIQUE. Zero or two candidates
%       is NO resolution, never a guess. Set 'PlateHandleJoin' false to disable
%       it; the report then shows those images as unresolved rather than
%       silently omitting them.
%
%   CONFLICT IS NOT RESOLVED BY PRECEDENCE. Both routes are evaluated and, if
%   they name different subjects, the image is left alone
%   (`unresolved_conflicting_candidates`) -- the rule ontologyRowSubjects sets.
%
%   ---------------------------------------------------------------------
%   THE PLURAL `document_id`: THE DATA DOES NOT DETERMINE IT
%   ---------------------------------------------------------------------
%   A row may name MANY referents. tableDocMaker.m:225-236:
%
%       values = tableRow{:,dependencyVariable};
%       for d = 1:numel(values)
%           ...
%           if isscalar(values)
%               doc = doc.set_dependency_value('document_id',value);     % ONE
%           else
%               doc = doc.add_dependency_value_n('document_id',value);   % MANY
%           end
%       end
%
%   THIS PASS REFUSES EVERY PLURAL ROW AND COUNTS IT
%   (`blocked_plural_document_id`). That is not caution; it is the only
%   available answer, and the writer proves it. tableDocMaker.m:170-172, sitting
%   immediately above the block that builds every descriptive field:
%
%       varNames = tableRow.Properties.VariableNames;
%       varNames(ismember(varNames,dependencyVariable)) = [];
%
%   `names`, `variableNames`, `ontologyNodes` and `data` are ALL built from
%   `varNames` AFTER that deletion (tableDocMaker.m:174-219). So a plural row
%   stores `document_id_1..n` in column order with NO surviving record of which
%   column produced which edge -- not in `data`, not in `variableNames`, not in
%   `ontologyNodes`. The edges are anonymous BY CONSTRUCTION, and the kinds
%   really do differ between writers: the same generic `document_id` slot is
%   pointed at a subject GROUP at +setup/+conv/+babu/import.m:531 and at a
%   SUBJECT at :580.
%
%   (Those two babu lines are cited elsewhere as evidence about
%   `ontologyTableRow`. THEY ARE NOT. Both sit on `generic_file` documents,
%   constructed at import.m:528 and :577. They remain the right evidence for the
%   KIND-VARIABILITY of the shared `document_id` idiom; they are not evidence
%   about this class. The distinction matters because the plural rule below is
%   justified by what the ROW writer does, not by what a sibling class does.)
%
%   So: the data does not determine it. Reported as an open question, with a
%   count, rather than guessed.
%
%   ---------------------------------------------------------------------
%   DELIBERATELY NOT DONE
%   ---------------------------------------------------------------------
%     * NOTHING IS MINTED. See above. `unresolved_no_plate_subject` counts the
%       images whose plate row exists but whose plate SUBJECT does not --
%       `resolveLawnPlateSubjects` withholds a tier's subject where that tier
%       has nothing measured about it ("It's only necessary to make all subjects
%       if we take measurements of both"). AN IMAGE OF A PLATE IS ARGUABLY
%       SOMETHING MEASURED ABOUT THAT PLATE, which would make those mints due --
%       but that is a change to THAT pass's rule and therefore a team call, not
%       a thing to bolt on here. The count is what the team needs to make it.
%     * NOTHING IS DELETED AND PASS 1 IS UNCHANGED. Every planned image is
%       re-folded through the existing migrator; a refusal leaves the document
%       exactly as pass 1 emitted it.
%     * NO SUBJECT PER IMAGE. The three imageStacks of one photograph (image /
%       mask / closest-patch, doImport.m:789/811/827) and every photograph of
%       one plate all resolve to the SAME plate subject. A subject per image
%       would assert that each photograph depicts a different thing.
%     * `ontology_image` IS RESOLVED AND COUNTED BUT NOT PLANNED. Re-folding one
%       changes nothing: +migrators_j/ontology_image.m tests `isVintageB` FIRST
%       and returns `{preBody}` before it ever looks for a subject, so a body
%       with `subject_id` added takes the identical passthrough arm. Planning it
%       would produce a pass that appears to work and does not.
%       `resolved_ontology_image_not_foldable` is the number that says what a
%       DID-side vintage-B arm keyed on the subject would be worth.
%     * NO `member_of`, `part_of` OR OTHER RELATION. The image becomes an
%       observation OF the plate; modelling anything further about the row is a
%       separate decision.
%
%   ---------------------------------------------------------------------
%   MEASURING THIS PASS: A ZERO ELSEWHERE CAN BE A TAUTOLOGY
%   ---------------------------------------------------------------------
%   `did2.validate.silentLoss` runs in PASS 1 (v1_to_v2.m:382), BEFORE any
%   post-pass. The corpus census therefore cannot see anything this pass does:
%   it counts a population that does not exist yet. Reading a zero for
%   "subject-less image_observations" out of a census and calling this pass
%   proven would be a tautology, not a result -- the trap the epoch
%   reconciliation (203c1f7) documents. THE REPORT BELOW IS THIS PASS'S OWN
%   INSTRUMENT and is the only place its denominators appear.
%
%   REPORT fields (denominators first, unconditionally):
%     ran                              false only if it returned before reading
%     v1_bodies_inspected              did_v1 bodies handed in
%     documents_inspected              migrated documents handed in
%     documents_unreadable             COUNTED, never dropped
%     v1_image_bodies                  did_v1 imageStack/ontologyImage bodies
%     images_passthrough               of the migrated set, still unconverted
%     image_stack_passthrough          ... the foldable half
%     ontology_image_passthrough       ... the not-yet-foldable half
%     images_converted_in_pass_1       had a subject already; nothing to do
%     table_rows_indexed               `ontology_table_row` documents in reach
%     subjects_indexed                 migrated documents that ARE a subject
%     plate_subjects_indexed           ... of those, ones with a plate handle
%     plate_handle_join_enabled        option state, so a zero is interpretable
%     resolved                         images whose subject is now known
%     resolved_via_row_edge            ... route 1
%     resolved_via_plate_handle        ... route 2
%     resolved_ontology_image_not_foldable   resolved but deliberately unplanned
%     images_planned                   PLAN entries (image_stack only)
%     distinct_subjects_attached       how many subjects the plan references
%     unresolved                       images left exactly as they are
%     unresolved_no_table_row_edge     image names no row
%     unresolved_table_row_not_in_batch   discovery mode; NOT proof of absence
%     unresolved_referent_not_a_table_row image's edge names a non-row
%     blocked_plural_document_id       THE UNDECIDABLE CASE -- a team question
%     unresolved_row_edge_missing      row's referent absent from the batch
%     unresolved_row_edge_not_a_subject   row's referent is not a subject
%     unresolved_no_plate_identifier   row names no plate
%     unresolved_no_plate_subject      plate known, subject withheld upstream
%     unresolved_plate_subject_ambiguous  two plate subjects -- never a guess
%     unresolved_conflicting_candidates   routes disagree
%     changed                          true iff PLAN is non-empty
%
%   See also: did2.convert.resolveLawnPlateSubjects,
%     ndi.migrate.internal.ontologyRowSubjects,
%     ndi.migrate.internal.ontologyLabelSubjects, ndi.migrate.local,
%     did2.convert.migrators_j.image_stack,
%     did2.convert.migrators_j.ontology_image.

arguments
    v1Bodies cell
    migratedStructs cell
    options.PlateHandleJoin (1,1) logical = true
end

% ---------------------------------------------------------------------
% THE DECLARED VOCABULARY, ISOLATED SO IT IS AUDITABLE IN ONE PLACE.
% ---------------------------------------------------------------------
% (1) The ONTOLOGY TERM NAME of the column naming the depicted plate, as it
%     appears in the lab dictionary +setup/+conv/+haley/tableDoc_dictionary.json:
%
%         "plateID": "EMPTY:bacterial plate identifier"
%
%     THE ONTOLOGY SHORT NAME IS NEVER GUESSED. The `EMPTY` table is not in this
%     repository (NDIC.txt lives in VH-Lab/ndi-ontology-matlab), so the spelling
%     `ndi.ontology.lookup` returns cannot be verified here -- and a disposition
%     that turns on an unverified spelling is exactly how `demo_ndi` went wrong.
%     Instead the short name is READ OUT OF THE DOCUMENT: `names` and
%     `variableNames` are built index-by-index from one lookup and joined in the
%     same order (tableDocMaker.m:196, :212-215), and `data`'s keys ARE those
%     short names (:208). So the row supplies its own term-name -> data-key
%     mapping; rowDataKeyFor() below uses it, normalises the comparison
%     (lowercase, non-alphanumerics stripped) and falls back to matching the data
%     key directly, so either spelling resolves.
PLATE_TERM = 'bacterial plate identifier';
%
% (2) The plate-handle SEPARATOR, which must agree with
%     did2.convert.resolveLawnPlateSubjects/plateHandle:
%
%         h = sprintf('exp/%s/plate/%s', char(expId), char(plateId));
%
%     This is a cross-repository coupling and it is named rather than inlined so
%     it is greppable from both ends. IT FAILS CLOSED: if that pass ever changes
%     its handle format, this join matches NOTHING, every affected image is
%     counted under `unresolved_no_plate_subject`, and the images stay exactly as
%     pass 1 emitted them. A silent wrong attachment is impossible; a visible
%     zero is what happens instead. testImagedEntitySubjects pins the format so
%     the drift reddens a test rather than only a counter.
PLATE_SEGMENT = '/plate/';

plan = emptyPlan();

% ---- denominators, computed and stored FIRST -----------------------------
report = struct();
report.ran                         = false;
report.v1_bodies_inspected         = numel(v1Bodies);
report.documents_inspected         = numel(migratedStructs);
report.documents_unreadable        = 0;
report.v1_image_bodies             = 0;
report.images_passthrough          = 0;
report.image_stack_passthrough     = 0;
report.ontology_image_passthrough  = 0;
report.images_converted_in_pass_1  = 0;
report.table_rows_indexed          = 0;
report.subjects_indexed            = 0;
report.plate_subjects_indexed      = 0;
report.plate_handle_join_enabled   = options.PlateHandleJoin;

report.resolved                             = 0;
report.resolved_via_row_edge                = 0;
report.resolved_via_plate_handle            = 0;
report.resolved_ontology_image_not_foldable = 0;

report.images_planned            = 0;
report.distinct_subjects_attached = 0;

report.unresolved                           = 0;
report.unresolved_no_table_row_edge         = 0;
report.unresolved_table_row_not_in_batch    = 0;
report.unresolved_referent_not_a_table_row  = 0;
report.blocked_plural_document_id           = 0;
report.unresolved_row_edge_missing          = 0;
report.unresolved_row_edge_not_a_subject    = 0;
report.unresolved_no_plate_identifier       = 0;
report.unresolved_no_plate_subject          = 0;
report.unresolved_plate_subject_ambiguous   = 0;
report.unresolved_conflicting_candidates    = 0;

report.changed = false;

v1Bodies = decodeBodies(v1Bodies);
[migratedStructs, unreadable] = decodeMigrated(migratedStructs);
report.documents_unreadable = unreadable;
report.ran = true;

if isempty(migratedStructs) || isempty(v1Bodies)
    return;
end

% ---- index the migrated set ----------------------------------------------
% Every document by id, so "the referent is not in this batch" (discovery mode,
% which is NOT evidence the referent does not exist -- jSessionAnchor's note is
% correct and is not being overridden) stays distinguishable from "the referent
% is here and is the wrong kind of thing". Those are different findings and
% collapsing them is how a passthrough gets graded benign.
byId          = containers.Map('KeyType', 'char', 'ValueType', 'any');
passthroughId = containers.Map('KeyType', 'char', 'ValueType', 'char');
plateSubjects = containers.Map('KeyType', 'char', 'ValueType', 'any');

for i = 1:numel(migratedStructs)
    s   = migratedStructs{i};
    id  = baseField(s, 'id', '');
    cls = classNameOf(s);
    if ~isempty(id)
        byId(id) = s;
    end
    if isImageClass(cls) && ~isempty(id)
        passthroughId(id) = cls;
        report.images_passthrough = report.images_passthrough + 1;
        if strcmp(cls, 'image_stack')
            report.image_stack_passthrough = report.image_stack_passthrough + 1;
        else
            report.ontology_image_passthrough = report.ontology_image_passthrough + 1;
        end
    end
    if isRowDoc(s)
        report.table_rows_indexed = report.table_rows_indexed + 1;
    end
    if ~isSubjectDoc(s)
        continue;
    end
    report.subjects_indexed = report.subjects_indexed + 1;
    plateId = plateIdOfHandle(subjectLocalIdentifier(s), PLATE_SEGMENT);
    if isempty(plateId) || isempty(id)
        continue;
    end
    report.plate_subjects_indexed = report.plate_subjects_indexed + 1;
    key = joinKey(baseField(s, 'session_id', ''), plateId);
    if isKey(plateSubjects, key)
        hits = plateSubjects(key);
        hits{end+1} = id; %#ok<AGROW>
        plateSubjects(key) = hits;
    else
        plateSubjects(key) = {id};
    end
end

% ---- walk the v1 image bodies --------------------------------------------
attached = {};

for i = 1:numel(v1Bodies)
    b = v1Bodies{i};
    if ~isImageBody(b)
        continue;
    end
    report.v1_image_bodies = report.v1_image_bodies + 1;

    srcId = baseField(b, 'id', '');
    if isempty(srcId) || ~isKey(passthroughId, srcId)
        % Pass 1 already folded this image (it had a subject), or it is not in
        % the migrated set at all. Either way there is nothing here to repair.
        report.images_converted_in_pass_1 = report.images_converted_in_pass_1 + 1;
        continue;
    end
    migratedClass = passthroughId(srcId);

    % --- hop 1: the image -> its ontology_table_row ------------------------
    [row, reason] = imageRowOf(b, byId);
    if isempty(row)
        report = bump(report, reason);
        report.unresolved = report.unresolved + 1;
        continue;
    end

    % --- hop 2: the row -> the subject of what is depicted -----------------
    [subjectId, route, reason] = depictedSubject(row, byId, plateSubjects, ...
        options.PlateHandleJoin, PLATE_TERM);
    if isempty(subjectId)
        report = bump(report, reason);
        report.unresolved = report.unresolved + 1;
        continue;
    end

    report.resolved = report.resolved + 1;
    if strcmp(route, 'row_edge')
        report.resolved_via_row_edge = report.resolved_via_row_edge + 1;
    else
        report.resolved_via_plate_handle = report.resolved_via_plate_handle + 1;
    end

    % `ontology_image` resolves but is NOT planned -- re-folding it is a no-op
    % (see the header). Counted, so the size of the deferral is a number.
    if ~strcmp(migratedClass, 'image_stack')
        report.resolved_ontology_image_not_foldable = ...
            report.resolved_ontology_image_not_foldable + 1;
        continue;
    end

    plan(end+1) = struct( ...          %#ok<AGROW>
        'source_id',  srcId, ...
        'subject_id', subjectId, ...
        'route',      route, ...
        'row_id',     baseField(row, 'id', ''), ...
        'body',       addSubjectDependency(b, subjectId));
    report.images_planned = report.images_planned + 1;
    attached{end+1} = subjectId; %#ok<AGROW>
end

report.distinct_subjects_attached = numel(unique(attached));
report.changed = ~isempty(plan);
end

% ===================== hop 1: image -> row ================================

function [row, reason] = imageRowOf(b, byId)
%IMAGEROWOF The `ontology_table_row` this image names, or [] with a reason.
%
%   BOTH edge names are accepted, because the two image classes spell one
%   relationship differently and neither spelling is renamed on the way through:
%   did2.convert.universalRenames.m:308 skips `depends_on` wholesale, so a
%   dependency NAME arrives verbatim in its did_v1 form.
%
%     imageStack     `document_id`          (haley/doImport.m:794,814,830)
%     ontologyImage  `ontologyTableRow_id`  (the template; imageDocMaker.m:131)
%
%   `ontology_table_row_id` is accepted too: that is the spelling V_eta's
%   tombstone declares, and +migrators_j/ontology_image.m's header flags the
%   camelCase/snake_case mismatch as raised-but-undecided. Reading all three
%   costs nothing; a copy that read only one would silently drop the edge.
row    = [];
reason = '';

vals = {};
for nm = {'document_id', 'ontologyTableRow_id', 'ontology_table_row_id'}
    vals = [vals, dependencyValuesMatching(b, nm{1})]; %#ok<AGROW>
end
vals = unique(nonEmpty(vals));

if isempty(vals)
    reason = 'unresolved_no_table_row_edge';
    return;
end
if ~isscalar(vals)
    % An image naming several documents is not this pass's puzzle to solve
    % either. Refuse; never pick one.
    reason = 'unresolved_referent_not_a_table_row';
    return;
end
if ~isKey(byId, vals{1})
    reason = 'unresolved_table_row_not_in_batch';
    return;
end
candidate = byId(vals{1});
if ~isRowDoc(candidate)
    reason = 'unresolved_referent_not_a_table_row';
    return;
end
row = candidate;
end

% ===================== hop 2: row -> subject ==============================

function [subjectId, route, reason] = depictedSubject(row, byId, plateSubjects, ...
    allowJoin, plateTerm)
%DEPICTEDSUBJECT The subject of what this row's image depicts, or '' + a reason.
%
%   Both routes are evaluated before either is accepted, so a disagreement is
%   VISIBLE rather than hidden behind a precedence order -- the rule
%   ontologyRowSubjects/resolveRowSubject already sets.
subjectId = '';
route     = '';
reason    = 'unresolved_no_plate_identifier';

hits = {};

% --- route 1: the row's own `document_id` edge ----------------------------
edgeVals = unique(nonEmpty(dependencyValuesMatching(row, 'document_id')));
sawEdge  = ~isempty(edgeVals);
if numel(edgeVals) > 1
    % UNDECIDABLE BY CONSTRUCTION: the writer deleted the column names that
    % would say which edge is which (see the header). Never a guess.
    reason = 'blocked_plural_document_id';
    return;
end
if sawEdge
    v = edgeVals{1};
    if ~isKey(byId, v)
        reason = 'unresolved_row_edge_missing';
    elseif isSubjectDoc(byId(v))
        hits{end+1} = {v, 'row_edge'}; %#ok<AGROW>
    else
        reason = 'unresolved_row_edge_not_a_subject';
    end
end

% --- route 2: the plate handle, session-scoped ----------------------------
if allowJoin
    [~, plateId] = rowDataKeyFor(row, plateTerm);
    if isempty(plateId)
        if ~sawEdge
            reason = 'unresolved_no_plate_identifier';
        end
    else
        key = joinKey(baseField(row, 'session_id', ''), plateId);
        if ~isKey(plateSubjects, key)
            % The plate is named but no subject carries its handle. Either
            % resolveLawnPlateSubjects withheld the tier (nothing measured about
            % the plate) or it refused for want of an expID. Both are ITS calls;
            % this is the count that tells the team how many images are waiting
            % on them.
            reason = 'unresolved_no_plate_subject';
        else
            matches = unique(plateSubjects(key));
            if isscalar(matches)
                hits{end+1} = {matches{1}, 'plate_handle'}; %#ok<AGROW>
            else
                reason = 'unresolved_plate_subject_ambiguous';
            end
        end
    end
end

% --- accept, or explain why not -------------------------------------------
if isempty(hits)
    return;
end
ids = cellfun(@(h) h{1}, hits, 'UniformOutput', false);
if numel(unique(ids)) > 1
    reason = 'unresolved_conflicting_candidates';
    return;
end
subjectId = hits{1}{1};
route     = hits{1}{2};
reason    = '';
end

% ===================== row / subject accessors ============================

function [key, value] = rowDataKeyFor(row, termName)
%ROWDATAKEYFOR The `data` key and value for an ontology TERM NAME.
%
%   The short name is never guessed: `names` and `variableNames` are built
%   index-by-index from one lookup and joined in the same order
%   (tableDocMaker.m:196, :212-215), and `data`'s field names ARE those short
%   names (:208), so the row supplies its own term-name -> data-key mapping. A
%   direct normalised match on the data key is accepted as a FALLBACK, so a row
%   with an empty `names` (or an ontology whose short name differs from the
%   dictionary key) still resolves.
key   = '';
value = '';
blk = rowBlock(row);
if ~isstruct(blk) || ~isfield(blk, 'data') || ~isstruct(blk.data) ...
        || ~isscalar(blk.data)
    return;
end
want = normaliseKey(termName);
fns  = fieldnames(blk.data);

% (a) via the row's own names <-> variableNames pairing
names  = splitList(getCharField(blk, 'names'));
shorts = splitList(getCharField(blk, 'variable_names'));
if isempty(shorts)
    shorts = splitList(getCharField(blk, 'variableNames'));
end
if numel(names) == numel(shorts)
    for k = 1:numel(names)
        if ~strcmp(normaliseKey(names{k}), want)
            continue;
        end
        for j = 1:numel(fns)
            if strcmp(normaliseKey(fns{j}), normaliseKey(shorts{k}))
                key   = fns{j};
                value = charOf(blk.data.(fns{j}));
                return;
            end
        end
    end
end

% (b) fallback: the data key itself, normalised
for j = 1:numel(fns)
    if strcmp(normaliseKey(fns{j}), want)
        key   = fns{j};
        value = charOf(blk.data.(fns{j}));
        return;
    end
end
end

function plateId = plateIdOfHandle(handle, segment)
%PLATEIDOFHANDLE The plate id a subject's local_identifier ENDS with, or ''.
%
%   `exp/0003/plate/0007`             -> '0007'   (a PLATE subject)
%   `exp/0003/plate/0007/patch/0002`  -> ''       (a LAWN subject -- it does not
%                                                  END with the plate segment)
%   `plate/0007`                      -> '0007'   (the pair-handle fallback
%                                                  resolveLawnPlateSubjects
%                                                  documents for C. elegans)
%
%   Reading only the TAIL is what keeps a lawn from being mistaken for its
%   plate, and it is why this pass does not need the expID hop at all.
plateId = '';
handle  = charOf(handle);
if isempty(handle)
    return;
end
idx = strfind(handle, segment);
if isempty(idx)
    % A bare `plate/<id>` prefix is the same statement without a leading path.
    bare = segment(2:end);            % 'plate/'
    if numel(handle) > numel(bare) && strncmp(handle, bare, numel(bare))
        tail = handle(numel(bare)+1:end);
        if ~any(tail == '/')
            plateId = tail;
        end
    end
    return;
end
last = idx(end);
tail = handle(last + numel(segment):end);
if isempty(tail) || any(tail == '/')
    return;      % something follows the plate id -- not a plate subject
end
plateId = tail;
end

function lid = subjectLocalIdentifier(s)
lid = '';
if isfield(s, 'subject') && isstruct(s.subject) && isscalar(s.subject) ...
        && isfield(s.subject, 'local_identifier')
    lid = charOf(s.subject.local_identifier);
end
end

function blk = rowBlock(b)
blk = struct();
if isstruct(b) && isfield(b, 'ontology_table_row') && isstruct(b.ontology_table_row)
    blk = b.ontology_table_row;
elseif isstruct(b) && isfield(b, 'ontologyTableRow') && isstruct(b.ontologyTableRow)
    blk = b.ontologyTableRow;
end
end

function tf = isRowDoc(s)
c = classNameOf(s);
tf = strcmp(c, 'ontology_table_row') || strcmp(c, 'ontologyTableRow');
end

function tf = isImageClass(c)
tf = strcmp(c, 'image_stack') || strcmp(c, 'ontology_image');
end

function tf = isImageBody(b)
% did_v1 spells them `imageStack` / `ontologyImage`; a body that has already been
% through universalRenames spells them snake_case (universalRenames.m:23 renames
% document_class.class_name). Accept both -- the idempotent re-run path
% (readBodiesFromVDelta) hands back migrated structs.
c = classNameOf(b);
tf = isImageClass(c) || strcmp(c, 'imageStack') || strcmp(c, 'ontologyImage');
end

function tf = isSubjectDoc(s)
% A `subject`, or anything whose superclass chain includes `subject`.
% Element-derived subjects reach here too: did2.convert.migrators_j.element
% promotes an element to a subject with its id PRESERVED. That is a recurring
% trap in this repo and it is recorded here so a reader does not re-derive it
% wrongly.
tf = false;
if ~isstruct(s)
    return;
end
if strcmp(classNameOf(s), 'subject')
    tf = true;
    return;
end
if isfield(s, 'document_class') && isstruct(s.document_class) ...
        && isfield(s.document_class, 'superclasses')
    sc = s.document_class.superclasses;
    for k = 1:numel(sc)
        if isstruct(sc) && isfield(sc(k), 'class_name') ...
                && strcmp(charOf(sc(k).class_name), 'subject')
            tf = true;
            return;
        end
    end
end
end

% ===================== dependency helpers =================================

function vals = dependencyValuesMatching(b, baseName)
%DEPENDENCYVALUESMATCHING Every depends_on value named BASENAME or BASENAME_<n>.
%   `add_dependency_value_n` is what tableDocMaker uses when a row names more
%   than one referent, so a single-name lookup would miss all but the scalar
%   case -- and the plural case is precisely the one that has to be DETECTED in
%   order to be refused.
vals = {};
if ~isstruct(b) || ~isfield(b, 'depends_on') || ~isstruct(b.depends_on)
    return;
end
deps = b.depends_on;
pattern = ['^' regexptranslate('escape', baseName) '(_\d+)?$'];
for k = 1:numel(deps)
    d = deps(k);
    if ~isfield(d, 'name')
        continue;
    end
    if isempty(regexp(charOf(d.name), pattern, 'once'))
        continue;
    end
    vals{end+1} = dependencyValueOf(d); %#ok<AGROW>
end
end

function v = dependencyValueOf(d)
% v1 writes {name,value} (or {name,id}); universalRenames rewrites both to
% {name,document_id}. Accept whichever is populated -- a copy that missed one
% would silently drop an edge.
v = '';
if isfield(d, 'document_id') && ~isempty(d.document_id)
    v = charOf(d.document_id);
elseif isfield(d, 'value') && ~isempty(d.value)
    v = charOf(d.value);
elseif isfield(d, 'id') && ~isempty(d.id)
    v = charOf(d.id);
end
end

function b = addSubjectDependency(b, subjectId)
%ADDSUBJECTDEPENDENCY Add `subject_id` to a v1 body's depends_on, matching the
%   existing struct array's field schema so the append is legal.
%
%   EVERY OTHER EDGE IS LEFT IN PLACE, and here that is load-bearing rather than
%   tidy: +migrators_j/image_stack.m carries the source `document_id` onto the
%   folded image_observation as `ontology_table_row_id`, so the provenance back
%   to the describing row survives the fold -- but only if the edge is still on
%   the body when it is re-folded.
entry = struct('name', 'subject_id', 'value', subjectId);
if isfield(b, 'depends_on') && isstruct(b.depends_on) && ~isempty(b.depends_on)
    fns = fieldnames(b.depends_on);
    if any(strcmp(fns, 'document_id')) && ~any(strcmp(fns, 'value'))
        entry = struct('name', 'subject_id', 'document_id', subjectId);
    elseif any(strcmp(fns, 'id')) && ~any(strcmp(fns, 'value')) ...
            && ~any(strcmp(fns, 'document_id'))
        entry = struct('name', 'subject_id', 'id', subjectId);
    end
    % Drop any pre-existing (necessarily EMPTY) subject_id so the append cannot
    % duplicate the name. A non-empty one cannot occur: the image would not have
    % been a passthrough.
    keep = true(1, numel(b.depends_on));
    for k = 1:numel(b.depends_on)
        if isfield(b.depends_on(k), 'name') ...
                && strcmp(charOf(b.depends_on(k).name), 'subject_id')
            keep(k) = false;
        end
    end
    deps = b.depends_on(keep);
    if isempty(deps)
        b.depends_on = entry;
    else
        entry = matchFields(entry, deps(1));
        deps(end+1) = entry;
        b.depends_on = deps;
    end
else
    b.depends_on = entry;
end
end

function entry = matchFields(entry, template)
% Give ENTRY exactly TEMPLATE's fields, in TEMPLATE's order, so a struct-array
% append does not error on a field mismatch.
val = dependencyValueOf(entry);
tf  = fieldnames(template);
out = struct();
for k = 1:numel(tf)
    switch tf{k}
        case 'name'
            out.name = entry.name;
        case {'document_id', 'value', 'id'}
            out.(tf{k}) = val;
        otherwise
            out.(tf{k}) = '';
    end
end
entry = out;
end

% ===================== small helpers ======================================

function p = emptyPlan()
p = struct('source_id', {}, 'subject_id', {}, 'route', {}, 'row_id', {}, ...
    'body', {});
end

function r = bump(r, field)
% Increment a named bucket. A name the report does not declare is a BUG, not a
% new bucket: a counter invented at runtime cannot report a zero, and a bucket
% that appears only when it fires is the omission operating rule 5 is about.
% Fail loudly instead of growing the struct.
if ~isfield(r, field)
    error('ndi:migrate:imagedEntitySubjects:unknownBucket', ...
        'Report has no bucket named "%s"; declare it with the denominators.', ...
        field);
end
r.(field) = r.(field) + 1;
end

function k = joinKey(sessionId, localId)
%JOINKEY Session-scoped, matching resolveLawnPlateSubjects/joinKey exactly.
%   `plateID` collides across the two Haley sessions (doImport.m:166 adds
%   expType*1000, :729 does not) and BOTH land in one ndi.dataset.dir, so an
%   unscoped key would attach C. elegans plates to E. coli images. The separator
%   is a character neither an NDI id nor a %.4i label contains.
k = [charOf(sessionId) '|' charOf(localId)];
end

function out = nonEmpty(c)
out = {};
for k = 1:numel(c)
    if ~isempty(c{k})
        out{end+1} = c{k}; %#ok<AGROW>
    end
end
end

function parts = splitList(s)
parts = {};
s = charOf(s);
if isempty(s)
    return;
end
parts = strtrim(strsplit(s, ','));
end

function out = normaliseKey(name)
% Lowercase and strip everything not alphanumeric, so 'bacterial plate
% identifier', 'BacterialPlateIdentifier' and 'bacterial_plate_identifier' are
% one key. A disposition that turns on a spelling is how `demo_ndi` went wrong.
out = lower(regexprep(charOf(name), '[^A-Za-z0-9]', ''));
end

function c = classNameOf(s)
c = '';
if isstruct(s) && isfield(s, 'document_class') && isstruct(s.document_class) ...
        && isfield(s.document_class, 'class_name')
    c = charOf(s.document_class.class_name);
end
end

function v = baseField(s, name, default)
v = default;
if isstruct(s) && isfield(s, 'base') && isstruct(s.base) ...
        && isfield(s.base, name) && ~isempty(s.base.(name))
    v = charOf(s.base.(name));
end
end

function v = getCharField(blk, name)
v = '';
if isstruct(blk) && isfield(blk, name)
    v = charOf(blk.(name));
end
end

function s = charOf(v)
s = '';
if ischar(v)
    s = v;
elseif isstring(v) && isscalar(v)
    s = char(v);
elseif iscell(v) && isscalar(v)
    s = charOf(v{1});
elseif isnumeric(v) && isscalar(v) && isfinite(v)
    s = num2str(v);
end
end

function out = decodeBodies(raw)
out = {};
for k = 1:numel(raw)
    b = raw{k};
    if ischar(b) || (isstring(b) && isscalar(b))
        try
            b = jsondecode(char(b));
        catch
            continue;
        end
    end
    if isstruct(b) && isscalar(b)
        out{end+1} = b; %#ok<AGROW>
    end
end
end

function [out, unreadable] = decodeMigrated(raw)
%DECODEMIGRATED Like decodeBodies, but COUNTS what it could not read.
%   A document dropped silently is a denominator that quietly shrinks, which is
%   how `silentLoss` reported zeros for two days.
out = {};
unreadable = 0;
for k = 1:numel(raw)
    b = raw{k};
    if ischar(b) || (isstring(b) && isscalar(b))
        try
            b = jsondecode(char(b));
        catch
            unreadable = unreadable + 1;
            continue;
        end
    end
    if isstruct(b) && isscalar(b) && ~isempty(fieldnames(b))
        out{end+1} = b; %#ok<AGROW>
    else
        unreadable = unreadable + 1;
    end
end
end
