function avi2mp4(inputSource, outputDir, options)
    arguments
        inputSource {mustBeTextScalar, mustBeNonempty}
        outputDir {mustBeTextScalar} = ""
        options.crf = []
        options.preset = []
        options.Overwrite logical = true % Added Overwrite option (default true)
    end
    
    % Standardize to char
    inputSource = char(inputSource);
    outputDir   = char(outputDir);
    
    % 1. Identify files
    if isfile(inputSource)
        [parent, name, ext] = fileparts(inputSource);
        filesToProcess = struct('name', [name, ext], 'folder', parent);
    elseif isfolder(inputSource)
        filesToProcess = dir(fullfile(inputSource, '*.avi'));
    else
        error('Input source must be a valid file or directory path.');
    end
    
    if isempty(filesToProcess)
        fprintf('No .avi files found to process.\n');
        return;
    end

    % 2. Prepare FFmpeg flags
    crfFlag = '';
    if ~isempty(options.crf), crfFlag = sprintf('-crf %d', options.crf); end
    
    presetFlag = '';
    if ~isempty(options.preset), presetFlag = sprintf('-preset %s', char(options.preset)); end
    
    % Determine the overwrite flag for FFmpeg (-y is overwrite, -n is skip)
    % However, we will handle the "Skip" logic in MATLAB for better logging
    if options.Overwrite, ovrFlag = '-y'; else, ovrFlag = '-n'; end

    % 3. Execution Loop
    for i = 1:length(filesToProcess)
        [~, fileName, ~] = fileparts(filesToProcess(i).name);
        
        if isempty(outputDir)
            thisOutputDir = filesToProcess(i).folder;
        else
            thisOutputDir = outputDir;
            if ~exist(thisOutputDir, 'dir'), mkdir(thisOutputDir); end
        end
        
        fullInput  = fullfile(filesToProcess(i).folder, filesToProcess(i).name);
        fullOutput = fullfile(thisOutputDir, [fileName, '_compressed.mp4']);
        
        % Check for existing file if Overwrite is FALSE
        if ~options.Overwrite && exist(fullOutput, 'file')
            fprintf('Skipping (%d/%d): %s (Already exists)\n', i, length(filesToProcess), fileName);
            continue;
        end
        
        fprintf('Processing (%d/%d): %s -> %s\n', i, length(filesToProcess), fileName, fullOutput);
        
        % Build the command (Note: %s before output is the overwrite flag)
        cmd = sprintf('ffmpeg -i "%s" -vcodec libx264 %s %s %s "%s"', ...
            fullInput, crfFlag, presetFlag, ovrFlag, fullOutput);
            
        [status, cmdOut] = system(cmd);
        
        if status ~= 0
            warning('Error processing %s:\n%s', fileName, cmdOut);
        end
    end
    
    fprintf('Process complete.\n');
end