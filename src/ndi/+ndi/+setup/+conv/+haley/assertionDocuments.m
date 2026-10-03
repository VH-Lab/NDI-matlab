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
%     cohort  species, strain  the worms' species and strain (from the spec's
%                              strain entry), stated once on the cohort with
%                              `distributive` true: they hold of each worm.
%     patch   species, strain  a patch with bacteria (a culture): OP50 on the
%                              C. elegans plates, OP50-GFP on the E. coli
%                              plates. A patch of LB alone gets none.
%     assay plate  inclusion in analysis = excluded, where the source excludes
%                              it (decision #2: tagged, not dropped). Per plate:
%                              no plate has some videos excluded and others not.
%   A strain assertion carries `strain_id`, the dataset-level strain document
%   (stage 2), and its name as the term, so it reads on its own.
%
%   The kind of each subject is NOT an assertion: it is subject.type
%   (sessionDocuments). Terms with no ontology node yet are plain names
%   (decision #55: an ontology lookup of all of them is to come).
%
%   Options:
%     'Strains'    the spec's `strains` entries (struct array or cell):
%                  key, name, species {node, name}
%     'StrainIds'  containers.Map, strain key -> document id (stage 2)
%
%   OUT fields: documents (cell of structs), counts (struct), skipped
%   (cellstr: an assertion not made, and why).

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
if ndi.setup.V2.schemaHasField('subject_statement', 'distributive')
    eachMember.distributive = true;
end

out = struct('documents', {{}}, 'skipped', {{}}, 'counts', struct( ...
    'cohort_species', 0, 'cohort_strain', 0, 'patch_species', 0, 'patch_strain', 0, ...
    'plate_excluded', 0));
hasBacteria = ismember('bacteria', S.Properties.VariableNames);
for k = 1:height(S)
    id = S.local_identifier{k};
    switch S.kind{k}
        case 'cohort'
            out = organismAssertions(out, id, S.strain{k}, 'cohort', eachMember);
        case 'patch'
            if hasBacteria && ~isempty(S.bacteria{k})
                out = organismAssertions(out, id, S.bacteria{k}, 'patch', struct());
            end
        case 'assay_plate'
            if S.exclude(k)
                out = assert1(out, id, 'inclusion in analysis', ...
                    did2.build.term('', 'excluded'), struct(), struct(), 'plate_excluded');
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
        out = assert1(out, id, 'species', did2.build.term(st.species.node, st.species.name), ...
            struct(), fields, [who '_species']);
        edges = struct();
        if isKey(options.StrainIds, strainKey)
            edges.strain_id = options.StrainIds(strainKey);
        else
            out.skipped{end+1} = sprintf('%s: no strain document for %s; strain asserted by name only', ...
                id, strainKey);
        end
        out = assert1(out, id, 'strain', did2.build.term('', st.name), edges, fields, ...
            [who '_strain']);
    end

    function out = assert1(out, id, variable, value, edges, fields, counter)
        if ~isKey(subjectIds, id)
            out.skipped{end+1} = sprintf('%s %s: not a subject of this session', id, variable);
            return;
        end
        out.documents{end+1} = did2.build.statement('term_assertion', subjectIds(id), ...
            variable, value, 'Edges', edges, 'Fields', fields, 'SessionId', sid);
        out.counts.(counter) = out.counts.(counter) + 1;
    end
end
