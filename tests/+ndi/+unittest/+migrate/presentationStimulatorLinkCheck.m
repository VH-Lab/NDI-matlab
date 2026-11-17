function R = presentationStimulatorLinkCheck(migratedNdiDir, label)
%PRESENTATIONSTIMULATORLINKCHECK Report-only: do the converted presentations carry the stimulator link?
%
%   SCRATCH MEASUREMENT (not for merge). For every v1 stimulus_presentation
%   in the v1 database beside the migrated one, reads the v2 document that
%   keeps its id and compares
%     instrument_id  with the v1 `stimulus_element_id` (the stimulator
%                    element), and checks that id is a v2 device entity
%     entity_id      with the v1 stimulator element's `subject_id` (the
%                    animal its `observes` relation names), and with the
%                    other end of the v2 `observes` relation on the
%                    stimulator.
%   Prints the denominator first, then the counts and up to 20 mismatches
%   of each kind.
S = ndi.migrate.internal.etaShape;
R = struct('label', label, 'presentations', 0, 'converted', 0, ...
    'instrument_is_stimulator', 0, 'instrument_is_device_entity', 0, ...
    'entity_is_stimulator_subject', 0, 'entity_is_observes_end', 0, ...
    'mismatches', {{}});
fprintf('\n  PRESENTATION STIMULATOR LINK CHECK (%s)\n', label);
dbs = dir(fullfile(char(migratedNdiDir), '*.sqlite'));
v2file = ''; v1file = '';
for k = 1:numel(dbs)
    p = fullfile(dbs(k).folder, dbs(k).name);
    try
        db = did2.database.sqlitedb(p);
        n = numel(db.allIds());
        db.close();
        if n > 0; v2file = p; end
    catch
        v1file = p;
    end
end
cand = fullfile(char(migratedNdiDir), 'did-sqlite.sqlite');
if isempty(v1file) && isfile(cand) && ~strcmp(cand, v2file)
    v1file = cand;
end
fprintf('    v2 database: %s\n    v1 database: %s\n', v2file, v1file);
if isempty(v2file) || isempty(v1file)
    fprintf('    NOT MEASURED: a database is missing\n');
    return;
end
% ---- v1: presentations and elements --------------------------------------
dbid = mksqlite(0, 'open', v1file);
rows = mksqlite(dbid, 'SELECT json_code FROM docs');
mksqlite(dbid, 'close');
v1 = containers.Map('KeyType', 'char', 'ValueType', 'any');
pres = {};
for k = 1:numel(rows)
    try
        b = jsondecode(rows(k).json_code);
    catch
        continue;
    end
    id = char(b.base.id);
    v1(id) = b;
    if strcmp(S.className(b), 'stimulus_presentation')
        pres{end+1} = id; %#ok<AGROW>
    end
end
R.presentations = numel(pres);
fprintf('    DENOMINATOR: %d v1 document(s) read, %d stimulus_presentation(s)\n', ...
    numel(rows), R.presentations);
% ---- v2: the observes relations, by stimulator ---------------------------
db = did2.database.sqlitedb(v2file);
cleanup = onCleanup(@() db.close());
observesEnds = containers.Map('KeyType', 'char', 'ValueType', 'any');
rels = db.search(did2.query('', 'isa', 'directed_relation'));
nObs = 0;
for k = 1:numel(rels)
    r = rels{k}.toStruct();
    if ~strcmp(S.relationName(r), 'observes'); continue; end
    nObs = nObs + 1;
    [c, p] = S.relationEnds(r);
    for e = {c, p}
        if isempty(e{1}); continue; end
        other = p; if strcmp(e{1}, p); other = c; end
        if isKey(observesEnds, e{1})
            observesEnds(e{1}) = [observesEnds(e{1}), {other}];
        else
            observesEnds(e{1}) = {other};
        end
    end
end
fprintf('    v2 directed_relation(s) read %d, observes %d\n', numel(rels), nObs);
classes = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(pres)
    pid = pres{k};
    b1 = v1(pid);
    stimIds = depValues(b1, 'stimulus_element_id');
    stim = ''; if ~isempty(stimIds); stim = stimIds{1}; end
    subj = '';
    if ~isempty(stim) && isKey(v1, stim)
        sv = depValues(v1(stim), 'subject_id');
        if ~isempty(sv); subj = sv{1}; end
    end
    d2 = getDoc(db, pid);
    cls = S.className(d2);
    if isempty(cls); cls = '(absent)'; end
    if isKey(classes, cls); classes(cls) = classes(cls) + 1; else; classes(cls) = 1; end
    if ~strcmp(cls, 'manipulation')
        R = note(R, sprintf('%s: v2 class %s (not a manipulation)', pid, cls));
        continue;
    end
    R.converted = R.converted + 1;
    ins = S.edge(d2, 'instrument_id');
    ent = S.edge(d2, 'entity_id');
    if numel(stimIds) ~= 1
        R = note(R, sprintf('%s: %d stimulus_element_id entries', pid, numel(stimIds)));
    end
    if ~isempty(ins) && strcmp(ins, stim)
        R.instrument_is_stimulator = R.instrument_is_stimulator + 1;
    else
        R = note(R, sprintf('%s: instrument_id "%s", stimulator "%s"', pid, ins, stim));
    end
    insDoc = getDoc(db, ins);
    if S.isEntity(insDoc, {'device'})
        R.instrument_is_device_entity = R.instrument_is_device_entity + 1;
    else
        R = note(R, sprintf('%s: instrument "%s" is a v2 %s of type "%s", not a device entity', ...
            pid, ins, S.className(insDoc), S.entityType(insDoc)));
    end
    if ~isempty(ent) && strcmp(ent, subj)
        R.entity_is_stimulator_subject = R.entity_is_stimulator_subject + 1;
    else
        R = note(R, sprintf('%s: entity_id "%s", stimulator subject "%s"', pid, ent, subj));
    end
    ends = {};
    if ~isempty(stim) && isKey(observesEnds, stim); ends = observesEnds(stim); end
    if any(strcmp(ends, ent))
        R.entity_is_observes_end = R.entity_is_observes_end + 1;
    else
        R = note(R, sprintf('%s: entity_id "%s"; the stimulator''s v2 observes names {%s}', ...
            pid, ent, strjoin(ends, ', ')));
    end
end
ks = classes.keys();
for k = 1:numel(ks)
    fprintf('    v2 class of the presentation id: %s %d\n', ks{k}, classes(ks{k}));
end
fprintf(['    converted to a manipulation %d of %d; instrument_id = stimulator %d; ' ...
    'instrument a v2 device entity %d; entity_id = the stimulator''s v1 subject %d; ' ...
    'entity_id = an end of the stimulator''s v2 observes %d\n'], R.converted, ...
    R.presentations, R.instrument_is_stimulator, R.instrument_is_device_entity, ...
    R.entity_is_stimulator_subject, R.entity_is_observes_end);
fprintf('    mismatches %d (first 20 below)\n', numel(R.mismatches));
for k = 1:min(20, numel(R.mismatches))
    fprintf('      %s\n', R.mismatches{k});
end
end

function R = note(R, s)
R.mismatches{end+1} = s;
end

function d = getDoc(db, id)
d = struct();
if isempty(id); return; end
try
    d = db.get(id).toStruct();
catch
    d = struct();
end
end

function v = depValues(b, name)
v = {};
if ~isfield(b, 'depends_on'); return; end
dep = b.depends_on;
if isstruct(dep); dep = num2cell(dep); end
for k = 1:numel(dep)
    if isfield(dep{k}, 'name') && strcmp(char(dep{k}.name), name) ...
            && isfield(dep{k}, 'value') && ~isempty(dep{k}.value)
        v{end+1} = char(dep{k}.value); %#ok<AGROW>
    end
end
end
