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

    arguments
        inputSource {mustBeTextScalar, mustBeNonempty}
        outputDir {mustBeTextScalar} = ""
        options.Overwrite logical = true
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
    rBinPath = '/usr/local/bin/Rscript'; 
    if ~exist(rBinPath, 'file')
        if exist('/opt/homebrew/bin/Rscript', 'file')
            rBinPath = '/opt/homebrew/bin/Rscript';
        else
            [status, result] = system('which Rscript');
            if status == 0
                rBinPath = strtrim(result);
            else
                error('NDI:prism2csv:RNotFound', 'Rscript not found. Please ensure R is installed.');
            end
        end
    end

    % 3. Standardize paths and arguments
    inputSource = char(inputSource);
    
    % If outputDir is empty, pass "NULL" so R knows to use the source directories
    if isempty(outputDir)
        outputDirArg = 'NULL';
    else
        outputDir = char(outputDir);
        if ~exist(outputDir, 'dir'), mkdir(outputDir); end
        outputDirArg = outputDir;
    end

    % Handle Overwrite logic (0 -> FALSE, 1 -> TRUE)
    ovrStrings = {'FALSE', 'TRUE'};
    ovrArg = ovrStrings{options.Overwrite + 1};

    % 4. Execute
    fprintf('Starting Prism to CSV conversion...\n');
    
    % Build the system command
    cmd = sprintf('"%s" "%s" "%s" "%s" "%s"', ...
        rBinPath, rScriptPath, inputSource, outputDirArg, ovrArg);
    
    % Execute with -echo to see R's output in the MATLAB console
    [status, cmdOut] = system(cmd, '-echo');
    
    if status ~= 0
        warning('NDI:prism2csv:RError', 'R process exited with an error:\n%s', cmdOut);
    else
        fprintf('Prism processing complete.\n');
    end
end