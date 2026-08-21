function numberOfWorkers = parallelWorkers(options)
% PARALLELWORKERS - how many workers a parallel loop should be allowed
%
%  N = ndi.fun.parallelWorkers()
%  N = ndi.fun.parallelWorkers('numberOfWorkers',N,'openPoolIfNone',TF)
%
%  Returns the number to give as the second argument of a parfor loop, so that
%  a calculation honours the user's parallel preferences:
%
%     n = ndi.fun.parallelWorkers();
%     parfor (i = 1:numel(x), n)
%        ...
%     end
%
%  N is 0 when the loop should run serially in the client, which is what parfor
%  does when its worker limit is 0. Results never depend on N; only the time
%  taken and the memory used do.
%
%  Two preferences decide the answer, both editable in
%  ndi.gui.preferencesEditor:
%
%    Parallel.OpenPoolIfNone  - open a pool when none is running. Default
%                               false, so NDI never starts a pool on its own:
%                               it uses a pool you opened, and otherwise runs
%                               serially.
%    Parallel.NumberOfWorkers - largest number of workers to allow. Default 0,
%                               meaning NDI sets no limit of its own.
%
%  Either may be overridden for a single call with the name/value pair of the
%  same name.
%
%  Why the default does not open a pool: every worker is a separate MATLAB
%  process, so a pool started without being asked for costs start-up time and a
%  multiple of MATLAB's memory, on a machine whose size NDI cannot know.
%  Deciding that is left to the person who does know. If the Parallel Computing
%  Toolbox is absent, or a pool cannot be started, the answer is 0 and the
%  calculation runs serially.
%
%  Example, allowing four workers from now on:
%     ndi.preferences.set('Parallel.OpenPoolIfNone',true);
%     ndi.preferences.set('Parallel.NumberOfWorkers',4);
%
%  See also: parfor, parpool, gcp, ndi.preferences, ndi.gui.preferencesEditor
%

arguments
    options.numberOfWorkers double = []
    options.openPoolIfNone = []
end

numberOfWorkers = 0;

 % The preferences, unless this call overrides them.
try
    maxWorkers = ndi.preferences.get('Parallel.NumberOfWorkers');
    openPoolIfNone = ndi.preferences.get('Parallel.OpenPoolIfNone');
catch
     % A preferences file that cannot be read is not a reason to fail a
     % calculation. Fall back to the shipped defaults.
    maxWorkers = 0;
    openPoolIfNone = false;
end

if ~isempty(options.numberOfWorkers)
    maxWorkers = options.numberOfWorkers;
end
if ~isempty(options.openPoolIfNone)
    openPoolIfNone = logical(options.openPoolIfNone);
end

 % gcp and parpool belong to the Parallel Computing Toolbox. Without it there
 % is no pool to have, and parfor runs serially regardless.
try
    pool = gcp('nocreate');
catch
    return;
end

if isempty(pool) && openPoolIfNone
    try
        if maxWorkers>0
            pool = parpool(maxWorkers);
        else
            pool = parpool();
        end
    catch ME
        warning('NDI:parallelWorkers:poolFailed',...
            'Could not start a parallel pool (%s). Running serially.',ME.message);
        pool = [];
    end
end

if isempty(pool)
    return;
end

numberOfWorkers = pool.NumWorkers;

if maxWorkers>0
    numberOfWorkers = min(numberOfWorkers,maxWorkers);
end
