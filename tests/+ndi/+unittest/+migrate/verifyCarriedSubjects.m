function n = verifyCarriedSubjects(testCase, result, v1Bodies, label)
%VERIFYCARRIEDSUBJECTS Every element whose subject NDI's second pass carried reads it back as v1.
%
%   N = ndi.unittest.migrate.verifyCarriedSubjects(TESTCASE, RESULT, V1BODIES, LABEL)
%   reads RESULT.secondPass.observesRetirement.carried_element_ids
%   (ndi.migrate.local): the migrated elements whose v1 subject the
%   statements made with them do not give back, held in the migration
%   report's carried fields ([no observes relation in v2], Jess Haley,
%   2026-11-26; Decided by Jess Haley, 2026-11-19, did-schema
%   did_v2_standing_wiring_plan.md: [stimulator subject carried as needing
%   information], [one-field carry in the migration report], [recording
%   probe subject carried the same way]; carry register row carry-172).
%   For each one, in a COPY of the migrated database opened as an NDI
%   session (so the calling test reads nothing this changed), it verifies:
%     * the carried subject (ndi.vintage.carriedSubjects) is the v1
%       element's `depends_on subject_id` (V1BODIES: the corpus as JSON text);
%     * ndi.vintage.elementFields reads that subject and `direct` true, one
%       at a time and batched (ndi.vintage.prefetchElementFields);
%     * session.getprobes, where it returns the element, gives it that
%       subject.
%   N is the number of elements checked; it prints the denominators first.

r = result.secondPass.observesRetirement;
testCase.assertTrue(isstruct(r) && isfield(r, 'carried_element_ids'), ...
    'the observesRetirement report lists no carried elements (the step did not run)');
ids = r.carried_element_ids;
n = 0;
fprintf('\n  CARRIED SUBJECTS (%s): %d element(s) retired with the subject carried\n', ...
    label, numel(ids));
if isempty(ids)
    return;
end

% the v1 subjects, from the corpus
v1Subject = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:numel(v1Bodies)
    t = v1Bodies{k};
    if ~ischar(t) && ~isstring(t)
        continue;
    end
    t = char(t);
    if ~contains(t, '"subject_id"')
        continue;
    end
    try
        b = jsondecode(t);
    catch
        continue;
    end
    if ~isfield(b, 'base') || ~any(strcmp(char(b.base.id), ids)) || ~isfield(b, 'depends_on')
        continue;
    end
    if iscell(b.depends_on)
        try
            b.depends_on = [b.depends_on{:}];
        catch
            continue;
        end
    end
    sj = ndi.migrate.internal.etaShape.edge(b, 'subject_id');
    if ~isempty(sj)
        v1Subject(char(b.base.id)) = sj;
    end
end
testCase.verifyEqual(double(v1Subject.Count), numel(ids), ...
    'a carried element has no v1 element with a subject_id in the corpus');

% a copy of the migrated .ndi, opened by session id
ndiDir = fileparts(result.destination);
copyRoot = tempname();
mkdir(copyRoot);
cleanCopy = onCleanup(@() removeDir(copyRoot)); %#ok<NASGU>
copyfile(ndiDir, fullfile(copyRoot, '.ndi'));
for f = {'unique_reference.txt', 'reference.txt', '.migrate.lock'}
    p = fullfile(copyRoot, '.ndi', f{1});
    if isfile(p); delete(p); end
end
db = did2.database.sqlitedb(fullfile(copyRoot, '.ndi', [name(result.destination)]));
sessionOf = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:numel(ids)
    s = db.get(ids{k}).toStruct();
    sid = edgeOf(s, 'session_id');
    if isempty(sid) && isfield(s.base, 'session_id')
        sid = char(s.base.session_id);
    end
    sessionOf(ids{k}) = sid;
end
db.close();

sessions = containers.Map('KeyType', 'char', 'ValueType', 'any');
probesOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
nProbe = 0;
for k = 1:numel(ids)
    id = ids{k};
    sid = sessionOf(id);
    if ~isKey(sessions, sid)
        sessions(sid) = ndi.session.dir(['carried ' label], copyRoot, sid);
        probesOf(sid) = sessions(sid).getprobes();
    end
    S = sessions(sid);
    want = '';
    if isKey(v1Subject, id); want = v1Subject(id); end
    [carried, found] = ndi.vintage.carriedSubjects(S, id);
    testCase.verifyTrue(found, sprintf('%s: element %s has no carried subject in the stored report', label, id));
    testCase.verifyEqual(carried, want, sprintf('%s: element %s carries another subject than v1', label, id));
    docs = S.database_search(ndi.query('base.id', 'exact_string', id, ''));
    testCase.assertNumElements(docs, 1, sprintf('%s: element %s not found', label, id));
    one = ndi.vintage.elementFields(docs{1}, S);
    testCase.verifyEqual(char(one.subject_id), want, ...
        sprintf('%s: element %s reads another subject than v1, one at a time', label, id));
    testCase.verifyTrue(logical(one.direct), sprintf('%s: element %s reads direct false', label, id));
    scope = ndi.vintage.elementFieldsScope('open'); %#ok<NASGU>
    ndi.vintage.prefetchElementFields(S, docs, false);
    batched = ndi.vintage.elementFields(docs{1}, S);
    clear scope
    testCase.verifyEqual(batched, one, sprintf('%s: element %s reads differently batched', label, id));
    P = probesOf(sid);
    for j = 1:numel(P)
        if strcmp(char(P{j}.id()), id)
            nProbe = nProbe + 1;
            testCase.verifyEqual(char(P{j}.subject_id), want, ...
                sprintf('%s: getprobes gives element %s another subject than v1', label, id));
        end
    end
    n = n + 1;
end
fprintf('    checked %d element(s) in %d session(s); %d returned by getprobes\n', ...
    n, double(sessions.Count), nProbe);
end

function v = edgeOf(s, nm)
v = ndi.migrate.internal.etaShape.edge(s, nm);
end

function f = name(p)
[~, a, b] = fileparts(p);
f = [a b];
end

function removeDir(d)
try
    if isfolder(d); rmdir(d, 's'); end
catch
end
end
