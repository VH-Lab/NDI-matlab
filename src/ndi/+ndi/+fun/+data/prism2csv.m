function prism2csv(inputSource, outputDir, options)
% PRISM2CSV Batch convert GraphPad Prism files to CSV using R.
%
%   PRISM2CSV(inputSource) converts the specified .prism file or all 
%   .prism files in the specified directory. Results are saved in the SAME
%   directory as the source files.
%
%   PRISM2CSV(inputSource, outputDir) saves the results to outputDir. 
%
%   PRISM2CSV(..., 'Overwrite', true/false) specifies whether to replace
%   existing CSV files. Default is true.
%
%   PRISM2CSV(..., 'RscriptPath', PATH) runs this Rscript (the program
%   that comes with R and runs R scripts). An explicit path always wins.
%   By default it is found with ndi.fun.findExecutable: the preference
%   Tools.RscriptPath, R_HOME, the usual install folders, then your
%   shell's PATH.
%
%   Requires R with the prism2R package installed.
%
%   See also: ndi.fun.findExecutable, ndi.fun.systemCommandLine

    arguments
        inputSource {mustBeTextScalar, mustBeNonempty}
        outputDir {mustBeTextScalar} = ""
        options.Overwrite logical = true
        options.Verbose logical = false
        options.RscriptPath (1,:) char = ''
    end

    % 1. Locate the R script relative to THIS .m file
    % mfilename('fullpath') gives the path to this script without the extension
    [thisFolder, ~, ~] = fileparts(mfilename('fullpath'));
    rScriptPath = fullfile(thisFolder, 'prism2csv.R');
    
    if ~exist(rScriptPath, 'file')
        error('NDI:prism2csv:ScriptNotFound', ...
            'The R script was not found in the same folder as the function: %s', rScriptPath);
    end

    % 2. Resolve the Rscript executable path
    rBinPath = findRscript(options.RscriptPath);

    % 3. Standardize paths and arguments
    inputSource = char(inputSource);
    
    % If outputDir is empty, pass "NULL" so R knows to use the source
    % directories. The default is the string "", for which isempty is
    % false, so compare characters, not elements.
    outputDir = char(outputDir);
    if isempty(outputDir)
        outputDirArg = 'NULL';
    else
        if ~exist(outputDir, 'dir'), mkdir(outputDir); end
        outputDirArg = outputDir;
    end

    % Handle Overwrite logic (0 -> FALSE, 1 -> TRUE)
    ovrStrings = {'FALSE', 'TRUE'};
    ovrArg = ovrStrings{options.Overwrite + 1};

    % 4. Execute
    fprintf('Starting Prism to CSV conversion...\n');
    
    % Build the system command (every argument quoted for this platform)
    cmd = ndi.fun.systemCommandLine(rBinPath, ...
        {rScriptPath, inputSource, outputDirArg, ovrArg});
    
    % Execute with -echo to see R's output in the MATLAB console
    if options.Verbose
        [status, cmdOut] = system(cmd, '-echo');
    else
        [status, cmdOut] = system(cmd);
    end
    
    if status ~= 0
        warning('NDI:prism2csv:RError', 'R process exited with an error:\n%s', cmdOut);
    else
        fprintf('Prism processing complete.\n');
    end
end

function rBinPath = findRscript(explicitPath)
% Find Rscript across platforms (see ndi.fun.findExecutable). Keeps the
% NDI:prism2csv:RNotFound identifier callers may already check for.
    folders = string.empty;
    if ispc
        % CRAN's installer: <ProgramFiles>\R\R-x.y.z\bin, or per user
        % under <LOCALAPPDATA>\Programs\R. Newest version first.
        for v = ["ProgramFiles", "LOCALAPPDATA"]
            root = getenv(v);
            if isempty(root), continue; end
            if v == "LOCALAPPDATA", root = fullfile(root, 'Programs'); end
            folders = [folders, string(fullfile(root, 'R', 'R-*', 'bin'))]; %#ok<AGROW>
        end
    elseif ismac
        % CRAN's macOS installer
        folders = "/Library/Frameworks/R.framework/Resources/bin";
    end
    try
        rBinPath = ndi.fun.findExecutable('Rscript', 'Path', explicitPath, ...
            'Preference', 'Tools.RscriptPath', ...
            'EnvironmentVariables', "R_HOME", ...
            'Folders', folders, ...
            'InstallHint', ['Install R (https://cran.r-project.org) and its ' ...
                'prism2R package, or set the preference ' ...
                'Tools.RscriptPath or pass ''RscriptPath''.']);
    catch ME
        if strcmp(ME.identifier, 'ndi:fun:findExecutable:notFound')
            error('NDI:prism2csv:RNotFound', '%s', ME.message);
        end
        rethrow(ME);
    end
end
