function out = assertionDocuments(session, S, subjectIds, options)
%ASSERTIONDOCUMENTS Stage 7 (Haley): what one session's subjects are.
%
%   OUT = ndi.setup.conv.haley.assertionDocuments(SESSION, S, SUBJECTIDS)
%   builds the term_assertion documents about the subjects of the one-row
%   session table SESSION (from sessionList, with `session_id` assigned). S
%   is the subject table (subjectList); SUBJECTIDS maps each subject's
%   local_identifier to its document id (sessionDocuments returns it).
%   Nothing is written here. Decision log #2, #55.
%
%   Assertions:
%     cohort  species (NCIT:C45293), strain (NCIT:C14419)
%                              the worms' species and strain (from the spec's
%                              strain entry), stated once on the cohort with
%                              `distributive` true: they hold of each worm.
%     patch   species, strain  a patch with bacteria (a culture): OP50 on the
%                              C. elegans assay and acclimation plates,
%                              OP50-GFP on the E. coli plates. A patch of LB
%                              alone gets none.
%     assay plate  inclusion in analysis (EMPTY:0000314) = false
%                              (logical_assertion), where the source excludes
%                              it (decision #2: tagged, not dropped). Per plate:
%                              no plate has some videos excluded and others not.
%                              Its reason, where one was written, is the
%                              statement's notes (or, with a schema whose
%                              statements have no notes, a text statement
%                              `reason for inclusion in analysis` beside it):
%                              the day's tableOfContents `notes` when that day
%                              is marked `include = no` (decision #73). The
%                              day's flag itself tags nothing: the lab's
%                              analysis excludes by plate.
%     assay plate  video recording (NCIT:C91063) = false (logical_assertion),
%                              on a plate never filmed (subjectList `filmed`
%                              false), noted "Prepared but not filmed: no
%                              video." (as above, a `reason for video
%                              recording` text statement with an older schema)
%                              (decision #73). Its worms are kept.
%     cohort  biological sex   hermaphrodite (PATO:0001340), from the spec's
%                              strain entry (`biological_sex`), distributive
%                              like species and strain. Only strains that
%                              state a sex get one, so a patch gets none.
%     assay-plate patch  diameter (PATO:0001334), length_assertion: the
%                              plate's target patch diameter (`lawnDiameter`,
%                              mm -> m), with condition value basis
%                              (EMPTY:0000298) = target (EMPTY:0000299): the
%                              design, not a measurement.
%     assay plate  spacing (NCIT:C45786), length_assertion: the plate's target
%                              patch spacing (`lawnSpacing`, mm -> m), with
%                              the same condition.
%   A strain assertion carries `strain_id`, the dataset-level strain document
%   (stage 2), and the strain's term -- its WBStrain node where the spec has
%   one (`node`), else its name alone -- so it reads on its own. On a schema
%   with one entity class the strain is an `instance_of` relation instead.
%   A logical or length assertion is made only when the schema in use can
%   build it (ndi.setup.V2.schemaHasLeaf); otherwise it is reported in
%   OUT.skipped.
%
%   The kind of each subject is NOT an assertion: it is subject.type
%   (sessionDocuments).
%
%   Options:
%     'Strains'    the spec's `strains` entries (struct array or cell):
%                  key, name, species {node, name}, and optionally
%                  node, biological_sex {node, name}
%     'StrainIds'  containers.Map, strain key -> document id (stage 2)
%
%   OUT fields: documents (cell of structs), counts (struct), skipped
%   (cellstr: an assertion not made, and why), targetIds (containers.Map:
%   assay plate local_identifier -> cellstr of the ids of its target
%   statements, its spacing and each of its patches' diameters, for a
%   calculation that used the design -- the lawn mask -- to list as inputs).

arguments
    session table
    S table
    subjectIds
    options.Strains = struct([])
    options.StrainIds = containers.Map()
end
if height(session) ~= 1
    error('ndi:setup:conv:haley:oneSession', 'Give exactly one session row.');
end
sid = char(session.session_id{1});
ref = char(session.local_identifier{1});
S = S(strcmp(S.session, ref), :);

strains = containers.Map();
list = options.Strains;
if isstruct(list), list = num2cell(list); end
for k = 1:numel(list)
    strains(list{k}.key) = list{k};
end
eachMember = struct();
if ndi.setup.V2.schemaHasField('statement', 'distributive')
    eachMember.distributive = true;
end

out = struct('documents', {{}}, 'skipped', {{}}, 'counts', struct( ...
    'cohort_species', 0, 'cohort_strain', 0, 'cohort_sex', 0, 'patch_species', 0, ...
    'patch_strain', 0, 'patch_sex', 0, 'plate_excluded', 0, 'plate_not_filmed', 0, ...
    'patch_target_diameter', 0, 'plate_target_spacing', 0), 'targetIds', containers.Map());
% the reason an excluded plate carries: the day's own note, where the day is
% marked `include = no` (decision #73)
dayReason = '';
if ismember('include', session.Properties.VariableNames) && ~session.include(1) ...
        && ismember('notes', session.Properties.VariableNames)
    dayReason = char(session.notes{1});
end
hasFilmed = ismember('filmed', S.Properties.VariableNames);
% a statement's notes (did-schema 2026-10-14: moved up from interaction)
statementHasNotes = ndi.setup.V2.schemaHasField('statement', 'notes');
schemaHasText = ndi.setup.V2.schemaHasClass('text');
hasBacteria = ismember('bacteria', S.Properties.VariableNames);
hasDiameter = ismember('lawn_diameter_mm', S.Properties.VariableNames);
hasSpacing = ismember('lawn_spacing_mm', S.Properties.VariableNames);
hasLogical = ndi.setup.V2.schemaHasLeaf('logical_assertion');
hasLength = ndi.setup.V2.schemaHasLeaf('length_assertion');
asTarget = did2.build.condition(haleyTerm('value basis'), 'Term', haleyTerm('target'));
for k = 1:height(S)
    id = S.local_identifier{k};
    switch S.kind{k}
        case 'cohort'
            out = organismAssertions(out, id, S.strain{k}, 'cohort', eachMember);
        case 'patch'
            if hasBacteria && ~isempty(S.bacteria{k})
                out = organismAssertions(out, id, S.bacteria{k}, 'patch', struct());
            end
            if hasDiameter
                out = target(out, id, regexprep(id, '_patch\d+$', ''), 'diameter', ...
                    S.lawn_diameter_mm(k), 'patch_target_diameter');
            end
        case 'assay_plate'
            if S.exclude(k)
                out = logical1(out, id, haleyTerm('inclusion in analysis'), 'plate_excluded', dayReason);
            end
            if hasFilmed && ~S.filmed(k)
                out = logical1(out, id, haleyTerm('video recording'), 'plate_not_filmed', ...
                    'Prepared but not filmed: no video.');
            end
            if hasSpacing
                out = target(out, id, id, 'spacing', S.lawn_spacing_mm(k), 'plate_target_spacing');
            end
    end
end

    function out = organismAssertions(out, id, strainKey, who, fields)
        if ~isKey(strains, strainKey)
            out.skipped{end+1} = sprintf('%s: strain %s is not in the spec; no species or strain', ...
                id, strainKey);
            return;
        end
        st = strains(strainKey);
        out = assert1(out, id, 'term_assertion', haleyTerm('species'), ...
            did2.build.term(st.species.node, st.species.name), struct(), fields, [who '_species']);
        if ndi.setup.V2.mergedEntities()
            % one entity class (2026-10-08): the subject is `instance_of` its strain
            % (V_eta_entity_composition_plan.md sec. 5); there is no strain assertion
            if ~isKey(options.StrainIds, strainKey)
                out.skipped{end+1} = sprintf('%s: no strain entity for %s; no strain recorded', ...
                    id, strainKey);
            elseif ~isKey(subjectIds, id)
                out.skipped{end+1} = sprintf('%s strain: not a subject of this session', id);
            else
                out.documents{end+1} = did2.build.directedRelation(subjectIds(id), ...
                    options.StrainIds(strainKey), did2.build.term('', 'instance_of'), ...
                    'Fields', fields, 'SessionId', sid);
                out.counts.([who '_strain']) = out.counts.([who '_strain']) + 1;
            end
            sexOf(st);
            return;
        end
        edges = struct();
        if isKey(options.StrainIds, strainKey)
            edges.strain_id = options.StrainIds(strainKey);
        else
            out.skipped{end+1} = sprintf('%s: no strain document for %s; strain asserted by name only', ...
                id, strainKey);
        end
        node = '';
        if isfield(st, 'node') && ~isempty(st.node), node = char(st.node); end
        out = assert1(out, id, 'term_assertion', haleyTerm('organism strain'), ...
            did2.build.term(node, st.name), edges, fields, [who '_strain']);
        sexOf(st);

        function sexOf(st)
            if isfield(st, 'biological_sex') && ~isempty(st.biological_sex)
                sx = st.biological_sex;
                out = assert1(out, id, 'term_assertion', did2.build.term('PATO:0000047', 'biological sex'), ...
                    did2.build.term(char(sx.node), char(sx.name)), struct(), fields, [who '_sex']);
            end
        end
    end

    function out = logical1(out, id, variable, counter, notes)
        % a false logical assertion: the plate is NOT what VARIABLE names
        if ~hasLogical
            out.skipped{end+1} = sprintf(['%s %s = false: the schema in use has no ' ...
                '`logical` value kind; not recorded'], id, variable.name);
            return;
        end
        out = assert1(out, id, 'logical_assertion', variable, false, struct(), struct(), ...
            counter, notes);
    end

    function out = target(out, subject, plate, name, mm, counter)
        % a design value (mm) stated as the subject's target, not measured
        if isnan(mm) || mm <= 0
            return;
        end
        if ~hasLength
            out.skipped{end+1} = sprintf(['%s target %s: the schema in use cannot build ' ...
                'a length_assertion; not recorded'], subject, name);
            return;
        end
        n = numel(out.documents);
        v = did2.build.valueCell('length', mm * 1e-3, 'SourceValue', mm, 'SourceUnit', 'mm');
        out = assert1(out, subject, 'length_assertion', haleyTerm(name), v, struct(), ...
            struct(), counter, '', asTarget);
        if numel(out.documents) > n
            ids = {};
            if isKey(out.targetIds, plate), ids = out.targetIds(plate); end
            out.targetIds(plate) = [ids, {out.documents{end}.base.id}];
        end
    end

    function out = assert1(out, id, leaf, variable, value, edges, fields, counter, notes, conditions)
        if nargin < 9
            notes = '';
        end
        if nargin < 10
            conditions = [];
        end
        if ~isKey(subjectIds, id)
            label = variable;
            if isstruct(label), label = label.name; end
            out.skipped{end+1} = sprintf('%s %s: not a subject of this session', id, label);
            return;
        end
        noteArgs = {};
        if ~isempty(notes) && statementHasNotes
            noteArgs = {'Notes', char(notes)};
        end
        if ~isempty(conditions)
            noteArgs = [noteArgs, {'Conditions', conditions}];
        end
        out.documents{end+1} = did2.build.statement(leaf, subjectIds(id), ...
            variable, value, 'Edges', edges, 'Fields', fields, 'SessionId', sid, noteArgs{:});
        out.counts.(counter) = out.counts.(counter) + 1;
        if ~isempty(notes) && ~statementHasNotes && ~schemaHasText
            % neither statement notes nor a text value kind: nowhere to put it
            if isstruct(variable), variable = variable.name; end
            out.skipped{end+1} = sprintf(['%s %s: the reason ("%s") is not recorded -- the ' ...
                'schema has neither statement notes nor a text value'], id, variable, char(notes));
        elseif ~isempty(notes) && ~statementHasNotes
            % a schema whose statements have no `notes` (did-schema before
            % 2026-10-14, when notes was on interaction only): the reason is
            % its own text statement beside it (decision #73)
            if isstruct(variable), variable = variable.name; end
            out.documents{end+1} = did2.build.statement('text_assertion', subjectIds(id), ...
                did2.build.term('', ['reason for ' variable]), ...
                did2.build.valueCell('text', {char(notes)}), 'SessionId', sid);
        end
    end
end
