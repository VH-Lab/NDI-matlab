function T = v2_object_layer_tryout(datasetPath, options)
%V2_OBJECT_LAYER_TRYOUT Try the V2 object layer on a real dataset, timing each step.
%
%   T = v2_object_layer_tryout(DATASETPATH) opens the V2 dataset at
%   DATASETPATH (the folder holding .ndi, e.g. <data>/haley_V2/dataset) and
%   asks it the questions the object layer exists for, through ndi.entity,
%   ndi.statement, ndi.entity and ndi.value, READ THROUGH THE DATASET:
%   things are found in one session (quick), then read through the
%   ndi.dataset, which also reaches the shared documents (software,
%   formulations, strains, people) that a session cannot. The last step
%   reads the same statements through the session, to show the
%   difference. Each step prints what it
%   found and how long it took; a step that errors is reported and the rest
%   still run. T is one row per step: step, ok, seconds, result.
%
%   Options:
%     'Session'  the session reference to open (default: the first
%                concentration session the dataset lists)
%
%   It writes nothing.
%
%   See also ndi.statement, ndi.entity, ndi.value,
%   src/ndi/docs/NDI-matlab/manual/developer/V2_Object_Layer.md.

arguments
    datasetPath (1,:) char {mustBeFolder}
    options.Session (1,:) char = ''
end

rows = cell(0, 4);
ctx = struct();

    function step(name, fn)
        fprintf('\n== %s ==\n', name);
        t0 = tic;
        try
            r = fn();
            ok = true;
        catch err
            r = sprintf('ERROR %s: %s', err.identifier, err.message);
            ok = false;
            fprintf('  %s\n', r);
            for k = 1:min(3, numel(err.stack))
                fprintf('    at %s:%d\n', err.stack(k).name, err.stack(k).line);
            end
        end
        sec = toc(t0);
        fprintf('  [%.3f s]\n', sec);
        rows(end+1, :) = {string(name), ok, sec, string(r)};
    end

% ---- the dataset and a session ---------------------------------------------------
step('open the dataset', @openDataset);
    function r = openDataset()
        ctx.ds = ndi.dataset.dir(datasetPath);
        [ctx.refs, ctx.ids] = ctx.ds.session_list();
        r = sprintf('%d session(s)', numel(ctx.refs));
        fprintf('  %s\n', r);
    end

step('open a session', @openSession);
    function r = openSession()
        ref = options.Session;
        if isempty(ref)
            ref = ctx.refs{find(startsWith(ctx.refs, 'concentration'), 1)};
        end
        ctx.S = ctx.ds.open_session(ctx.ids{strcmp(ctx.refs, ref)});
        r = ref;
        fprintf('  %s\n', r);
    end

% ---- subjects ---------------------------------------------------------------------
step('ndi.entity.search: every subject in the session', @allSubjects);
    function r = allSubjects()
        s = ndi.entity.search(ctx.S);
        types = cellfun(@(x) string(x.type()), s);
        [u, ~, j] = unique(types);
        n = accumarray(j(:), 1);
        parts = arrayfun(@(k) sprintf('%s %d', u(k), n(k)), 1:numel(u), 'UniformOutput', false);
        r = sprintf('%d subject(s): %s', numel(s), strjoin(parts, ', '));
        fprintf('  %s\n', r);
    end

step('ndi.entity.search: every subject in the dataset', @allSubjectsDataset);
    function r = allSubjectsDataset()
        s = ndi.entity.search(ctx.ds);
        r = sprintf('%d subject(s) in %d session(s)', numel(s), numel(ctx.refs));
        fprintf('  %s\n', r);
    end

step('ndi.statement.search: the speed calculations in the session', @speeds);
    function r = speeds()
        ctx.sp = ndi.statement.search(ctx.S, 'Class', 'velocity_calculation');
        r = sprintf('%d velocity_calculation(s)', numel(ctx.sp));
        fprintf('  %s\n', r);
    end

step('the worm of the first one, read through the dataset', @worm);
    function r = worm()
        ctx.wS = ctx.sp{1}.subject();
        ctx.w = ndi.entity.fromDocument(ctx.ds, ctx.wS.document_id());
        r = sprintf('%s (%s), %s', ctx.w.local_identifier, ctx.w.type, ctx.w.document_id);
        fprintf('  %s\n', r);
    end

step('ndi.entity.search by LocalIdentifier, in the dataset', @byLocal);
    function r = byLocal()
        x = ndi.entity.search(ctx.ds, 'LocalIdentifier', ctx.w.local_identifier);
        r = sprintf('%d found', numel(x));
        fprintf('  %s\n', r);
    end

step('the worm''s statements, by kind', @wormStatements);
    function r = wormStatements()
        st = ctx.w.statements();
        k = cellfun(@(x) string(x.kind()) + " / " + string(x.variable_name()), st);
        [u, ~, j] = unique(k);
        n = accumarray(j(:), 1);
        for i = 1:numel(u), fprintf('  %3d  %s\n', n(i), u(i)); end
        r = sprintf('%d statement(s)', numel(st));
    end

% ---- a value from its body -------------------------------------------------------
step('its speed: value() decoded from the body', @speedValue);
    function r = speedValue()
        st = ctx.w.statements('Class', 'velocity_calculation', 'Variable', 'midpoint speed');
        if isempty(st), st = ctx.w.statements('Class', 'velocity_calculation'); end
        ctx.speed = st{1};
        v = st{1}.value();
        d = double(v);
        fprintf('  variable: %s; class %s; unit %s; size %s\n', st{1}.variable_name(), ...
            v.class_name, v.unit(), mat2str(size(d)));
        fprintf('  first values: %s\n', mat2str(d(1:min(5, end))', 4));
        fprintf('  median %.4g, max %.4g (%d NaN)\n', median(d, 'omitnan'), max(d), nnz(isnan(d)));
        disp(v.axes());
        r = sprintf('%s %s, median %.4g %s', st{1}.variable_name(), mat2str(size(d)), ...
            median(d, 'omitnan'), v.unit());
    end

step('what the speed was computed from (inputs)', @inputs);
    function r = inputs()
        in = ctx.speed.inputs();
        names = cellfun(@describe, in, 'UniformOutput', false);
        for i = 1:numel(names), fprintf('  %s\n', names{i}); end
        r = strjoin(names, '; ');
    end

step('how: method, parameters, software, time', @how);
    function r = how()
        fprintf('  method: %s\n', ctx.speed.method_name());
        disp(ctx.speed.method_parameters());
        sw = ctx.speed.software();
        fprintf('  software: %s\n', strjoin(cellfun(@(x) x.name(), sw, 'UniformOutput', false), ', '));
        t = ctx.speed.time();
        for i = 1:numel(t)
            fprintf('  time: %s, %s to %s (resolved by %s)\n', t(i).kind, string(t(i).start), ...
                string(t(i).end), t(i).resolved_by);
        end
        r = sprintf('%s; %d time reference(s)', ctx.speed.method_name(), numel(t));
    end

% ---- groups, parts, assertions ----------------------------------------------------
step('the worm''s cohort and its members', @cohort);
    function r = cohort()
        g = ctx.w.memberOf();
        ctx.cohort = g{1};
        m = ctx.cohort.members();
        r = sprintf('%s: %d member(s)', ctx.cohort.local_identifier, numel(m));
        fprintf('  %s\n', r);
    end

step('the cohort''s assertions', @assertions);
    function r = assertions()
        A = ctx.cohort.assertions();
        disp(A);
        r = strjoin(A.variable + " = " + A.value, '; ');
    end

step('the cohort''s relations (places over time)', @relations);
    function r = relations()
        R = ctx.cohort.relations();
        disp(R(:, {'relation', 'direction', 'other_id'}));
        r = sprintf('%d relation(s)', height(R));
    end

step('a plate and its patches (part_of)', @plate);
    function r = plate()
        p = ctx.cohort.parents('contained_in');
        names = cellfun(@(x) x.local_identifier, p, 'UniformOutput', false);
        fprintf('  the cohort was in: %s\n', strjoin(names, ', '));
        pl = p{find(contains(names, 'assayPlate'), 1)};
        parts = pl.parts();
        r = sprintf('%s has %d part(s): %s', pl.local_identifier, numel(parts), ...
            strjoin(cellfun(@(x) x.local_identifier, parts, 'UniformOutput', false), ', '));
        fprintf('  %s\n', r);
        ctx.plate = pl;
    end

% ---- manipulations ------------------------------------------------------------------
step('the plate''s manipulations, with time and dose', @manipulations);
    function r = manipulations()
        mm = ctx.plate.statements('Class', 'manipulation');
        for i = 1:numel(mm)
            v = mm{i}.value();
            t = mm{i}.time();
            when = 'no time';
            if ~isempty(t), when = sprintf('%s %s', t(1).kind, string(t(1).start)); end
            fprintf('  %-26s %-24s %-22s %s\n', mm{i}.kind(), mm{i}.variable_name(), ...
                mm{i}.method_name(), when);
            if strcmp(v.class_name, 'dose'), ctx.dose = mm{i}; end
        end
        r = sprintf('%d manipulation(s)', numel(mm));
    end

step('the dose''s formulation', @formulation);
    function r = formulation()
        f = ctx.dose.formulation();
        if isempty(f)
            r = 'not found';
        else
            r = sprintf('found: %s; fields %s', f.class_name, strjoin(fieldnames(f.raw), ', '));
        end
        fprintf('  %s\n', r);
    end

% ---- dataset-level ------------------------------------------------------------------
step('dataset-level entities (people, organizations, studies, strains)', @entities);
    function r = entities()
        out = {};
        for k = {'person', 'organization', 'study', 'strain', 'software'}
            e = ndi.entity.search(ctx.ds, k{1});
            names = cellfun(@(x) x.name(), e, 'UniformOutput', false);
            fprintf('  %-12s %3d  %s\n', k{1}, numel(e), strjoin(names(1:min(5, end)), ', '));
            out{end+1} = sprintf('%s %d', k{1}, numel(e)); %#ok<AGROW>
        end
        r = strjoin(out, ', ');
    end

step('the dataset''s model fits (statement.find on the dataset)', @fits);
    function r = fits()
        f = ndi.statement.search(ctx.ds, 'Class', 'model_fit_calculation');
        r = sprintf('%d model_fit_calculation(s)', numel(f));
        fprintf('  %s\n', r);
    end

% ---- the same, through the session ---------------------------------------------------
step('the same worm read through the SESSION instead (for comparison)', @throughSession);
    function r = throughSession()
        st = ctx.wS.statements();
        sp = ctx.wS.statements('Class', 'velocity_calculation', 'Variable', ctx.speed.variable_name());
        nSw = numel(sp{1}.software());
        nF = 0;
        dm = ndi.statement.fromDocument(ctx.S, ctx.dose.document_id());
        if ~isempty(dm.formulation()), nF = 1; end
        r = sprintf(['%d statement(s); speed software found: %d (dataset: %d); ' ...
            'formulation found: %d (dataset: 1)'], numel(st), nSw, numel(ctx.speed.software()), nF);
        fprintf('  %s\n', r);
    end

% ---- summary --------------------------------------------------------------------------
T = cell2table(rows, 'VariableNames', {'step', 'ok', 'seconds', 'result'});
fprintf('\n== summary: %d step(s), %d ok, %d failed, %.1f s in all ==\n', height(T), ...
    nnz(T.ok), nnz(~T.ok), sum(T.seconds));
disp(T(:, {'step', 'ok', 'seconds'}));
end

function s = describe(x)
if isa(x, 'ndi.statement')
    s = sprintf('%s: %s', x.kind(), x.variable_name());
else
    p = ndi.v2.props(x);
    s = sprintf('%s %s', p.document_class.class_name, p.base.id);
end
end
