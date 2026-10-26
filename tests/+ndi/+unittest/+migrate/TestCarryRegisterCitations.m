classdef TestCarryRegisterCitations < matlab.unittest.TestCase
%TESTCARRYREGISTERCITATIONS Every carry register row NDI's second pass cites exists.
%
%   Decided by Jess Haley, 2026-10-26 [carry register] (did-schema
%   schemas/V_eta_go_forward_class_audit.md): every reason the generic
%   migration carries a v1 document whole as v1 is a row of ONE register,
%   did-schema schemas/V_eta_carry_register.json, and every carry note a
%   migrator writes cites its row. Her decision of the same day ("1. Yes")
%   extends this to NDI-matlab's second pass, like DID-matlab's notes
%   (DID-matlab tools/check_carry_citations.py).
%
%   NDI's second pass (src/ndi/+ndi/+migrate) cites a row with a
%   `[carry-NNN]` tag placed before the reason it covers, or with the row id
%   it records for a document it leaves (REPORT.carry_rows), and a
%   `% carry-register:` comment above the site names the row(s) that site
%   can cite.
%
%   FAILS on:
%     - a `carry-NNN` token anywhere under src/ndi/+ndi/+migrate that is not a
%       row id of the register (a citation of a row that does not exist);
%     - a file whose code cites a row its `% carry-register:` markers do not
%       name, or whose markers name a row its code does not cite;
%     - nothing read: no register row, no file, or no citation (a check
%       that inspected nothing is not a pass).
%
%   THE REGISTER IS READ FROM THE did-schema CHECKOUT THE CI ALREADY USES
%   (run-tests.yml and test-eta-migrate-e2e.yml check did-schema out at
%   ./did-schema): $DID_SCHEMA_ROOT, else ./did-schema, else ../did-schema,
%   else ../DID-schema. On CI (GITHUB_ACTIONS set) a missing register fails;
%   elsewhere the test is filtered with the reason.
%
%   ORDER: the rows NDI cites land in did-schema first (did-schema PR #151
%   and the NDI rows carry-062 onward); until they are on the did-schema
%   ref the CI checks out, this test FAILS and names the missing ids.

    properties (Constant)
        TokenPattern = 'carry-\d{3}'
        MarkerPattern = '^\s*%\s*carry-register:(.*)$'
    end

    methods (Test)
        function testEveryCitedRowIsInTheRegister(testCase)
            [ids, regPath] = readRegister(testCase);
            cites = scanCitations();
            fprintf(['DENOMINATOR: %d carry register row(s) read from %s; ' ...
                '%d file(s) scanned under src/ndi/+ndi/+migrate; ' ...
                '%d citation(s) of %d distinct row(s)\n'], numel(ids), regPath, ...
                cites.files, numel(cites.token), numel(unique(cites.token)));
            testCase.verifyGreaterThan(numel(ids), 0, ...
                'the carry register holds no rows: nothing was checked');
            testCase.verifyGreaterThan(cites.files, 0, 'no source file was scanned');
            testCase.verifyGreaterThan(numel(cites.token), 0, ...
                'no carry register citation was found: nothing was checked');
            missing = ~ismember(cites.token, ids);
            if any(missing)
                lines = strcat(cites.where(missing), {': '}, cites.token(missing));
                testCase.verifyFail(sprintf(['%d citation(s) name a row the carry ' ...
                    'register (%s) does not hold: %s.\nThe rows must land in ' ...
                    'did-schema first (did-schema PR #151, then the NDI rows ' ...
                    'carry-062 onward), then this branch.\n%s'], nnz(missing), ...
                    regPath, strjoin(unique(cites.token(missing)), ', '), ...
                    strjoin(lines, newline)));
            end
        end

        function testMarkersMatchTheCode(testCase)
            cites = scanCitations();
            testCase.verifyGreaterThan(numel(cites.file_rows), 0, ...
                'no file cites a carry register row');
            for k = 1:numel(cites.file_rows)
                f = cites.file_rows(k);
                unmarked = setdiff(f.code, f.marked);
                testCase.verifyEmpty(unmarked, sprintf(['%s cites %s in code ' ...
                    'with no %% carry-register: marker naming it'], f.file, ...
                    strjoin(unmarked, ', ')));
                unused = setdiff(f.marked, f.code);
                testCase.verifyEmpty(unused, sprintf(['%s has a %% carry-register: ' ...
                    'marker naming %s, which its code does not cite'], f.file, ...
                    strjoin(unused, ', ')));
            end
        end
    end
end

% ---- helpers --------------------------------------------------------------

function root = repoRoot()
% tests/+ndi/+unittest/+migrate/<this file> -> the repository root
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(fileparts(fileparts(here))));
end

function [ids, regPath] = readRegister(testCase)
rel = fullfile('schemas', 'V_eta_carry_register.json');
root = repoRoot();
candidates = {};
env = getenv('DID_SCHEMA_ROOT');
if ~isempty(env)
    candidates{end+1} = env;
end
candidates = [candidates, {fullfile(root, 'did-schema'), ...
    fullfile(fileparts(root), 'did-schema'), fullfile(fileparts(root), 'DID-schema')}];
regPath = '';
for k = 1:numel(candidates)
    p = fullfile(candidates{k}, rel);
    if isfile(p)
        regPath = p;
        break;
    end
end
msg = sprintf(['no did-schema checkout holding %s (looked in: %s); set ' ...
    'DID_SCHEMA_ROOT'], rel, strjoin(candidates, ', '));
if isempty(regPath)
    if ~isempty(getenv('GITHUB_ACTIONS'))
        testCase.assertFail(msg);
    else
        testCase.assumeFail(msg);
    end
end
reg = jsondecode(fileread(regPath));
rows = {};
if isstruct(reg) && isfield(reg, 'rows')
    rows = reg.rows;
end
if isstruct(rows)
    rows = num2cell(rows);
end
ids = {};
for k = 1:numel(rows)
    r = rows{k};
    if isstruct(r) && isfield(r, 'id')
        ids{end+1} = char(r.id); %#ok<AGROW>
    end
end
end

function c = scanCitations()
%SCANCITATIONS Every carry-NNN token under src/ndi/+ndi/+migrate, and per
%   file the rows its code cites and the rows its markers name.
src = fullfile(repoRoot(), 'src', 'ndi', '+ndi', '+migrate');
listing = dir(fullfile(src, '**', '*.m'));
c.files = numel(listing);
c.token = {};
c.where = {};
c.file_rows = struct('file', {}, 'code', {}, 'marked', {});
tokenPat = ndi.unittest.migrate.TestCarryRegisterCitations.TokenPattern;
markerPat = ndi.unittest.migrate.TestCarryRegisterCitations.MarkerPattern;
for k = 1:numel(listing)
    path = fullfile(listing(k).folder, listing(k).name);
    lines = splitlines(string(fileread(path)));
    code = {};
    marked = {};
    inMarker = false;
    for n = 1:numel(lines)
        line = char(lines(n));
        toks = regexp(line, tokenPat, 'match');
        for t = 1:numel(toks)
            c.token{end+1} = toks{t};
            c.where{end+1} = sprintf('%s:%d', erase(path, [repoRoot() filesep]), n);
        end
        m = regexp(line, markerPat, 'tokens', 'once');
        isComment = startsWith(strtrim(line), '%');
        if ~isempty(m)
            marked = [marked, regexp(m{1}, tokenPat, 'match')]; %#ok<AGROW>
            inMarker = true;
        elseif isComment && inMarker
            % a marker's continuation lines
            marked = [marked, regexp(line, tokenPat, 'match')]; %#ok<AGROW>
        else
            inMarker = false;
            if ~isComment
                codePart = line;
                pct = strfind(codePart, '%');
                % a '%' inside a quoted string (sprintf formats) is code, so
                % only a trailing comment after the last quote is dropped
                q = strfind(codePart, '''');
                if ~isempty(pct) && (isempty(q) || pct(end) > q(end))
                    codePart = codePart(1:pct(end) - 1);
                end
                code = [code, regexp(codePart, tokenPat, 'match')]; %#ok<AGROW>
            end
        end
    end
    if ~isempty(code) || ~isempty(marked)
        c.file_rows(end+1) = struct('file', erase(path, [repoRoot() filesep]), ...
            'code', {unique(code)}, 'marked', {unique(marked)});
    end
end
end
