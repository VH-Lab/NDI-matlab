function [userSelection, backedUpSuccessfully, originalFileDeleted] = askReuseTempFile(app, tempWorkingFilePath)
% ASKREUSETEMPFILE - Asks the user if they want to reuse an existing temporary working file.
% Handles backup and deletion if "Start Over" is chosen.
%
% Inputs:
%   app - The MetadataEditorApp instance (for UI interactions like uiconfirm, inform, alert).
%   tempWorkingFilePath - The full path to the temporary working file (e.g., NDIMetadataEditorData.mat).
%
% Outputs:
%   userSelection - String: 'Continue' or 'Start Over'. If the file doesn't exist, defaults to 'Start Over'.
%   backedUpSuccessfully - Logical: True if backup was successful (relevant for 'Start Over').
%   originalFileDeleted - Logical: True if the original temp file was deleted (relevant for 'Start Over' after successful backup).

    userSelection = 'Start Over'; % Default if file doesn't exist or other issues
    backedUpSuccessfully = false;
    originalFileDeleted = false;

    if isfile(tempWorkingFilePath)
        question = 'A previous temporary working file (NDIMetadataEditorData.mat) was found. Do you want to continue where you left off or start over?';
        title = 'Resume Previous Session?';
        selectionDialog = uiconfirm(app.NDIMetadataEditorUIFigure, question, title, ...
            'Options', {'Continue', 'Start Over'}, 'DefaultOption', 'Continue', 'CancelOption', 'Continue');
        
        userSelection = selectionDialog; % Capture user's direct choice

        if strcmp(userSelection, 'Start Over')
            % Attempt to backup the existing file
            try
                [dirPath, fileName, fileExt] = fileparts(tempWorkingFilePath);
                backupCounter = 1;
                backupFilePath = fullfile(dirPath, sprintf('%s-bkup%d%s', fileName, backupCounter, fileExt));
                while isfile(backupFilePath)
                    backupCounter = backupCounter + 1;
                    backupFilePath = fullfile(dirPath, sprintf('%s-bkup%d%s', fileName, backupCounter, fileExt));
                end
                copyfile(tempWorkingFilePath, backupFilePath);
                app.inform(sprintf('Previous temporary working file data backed up to:\n%s', backupFilePath), 'Backup Created');
                backedUpSuccessfully = true;
            catch ME_copy
                app.alert(sprintf('Could not back up existing temporary working file. Error: %s. Please check file permissions.', ME_copy.message), 'Backup Failed');
                backedUpSuccessfully = false; % Explicitly set
                
                % As per user request: if backup fails, try to delete and proceed with empty.
                try
                    delete(tempWorkingFilePath);
                    app.inform('Original temporary working file has been deleted as per "Start Over" preference, despite backup failure. Proceeding with an empty session.', 'File Deleted');
                    originalFileDeleted = true; 
                    % userSelection remains 'Start Over', backedUpSuccessfully is false.
                    % The caller will see 'Start Over', backedUpSuccessfully=false, originalFileDeleted=true
                    % and should proceed with an empty session.
                    return; % Exit as we've handled the "Start Over" by deletion
                catch ME_delete_after_failed_backup
                    app.alert(sprintf('Failed to back up AND also failed to delete the original temporary working file. Error during delete: %s. Proceeding by loading the existing file.', ME_delete_after_failed_backup.message), 'Operation Incomplete');
                    userSelection = 'Continue'; % Force continue if delete also fails
                    % backedUpSuccessfully is false, originalFileDeleted is false.
                    % Caller will see 'Continue' and load the existing file.
                    return;
                end
            end

            if backedUpSuccessfully
                % Attempt to delete the original file only if backup was successful
                try
                    delete(tempWorkingFilePath);
                    originalFileDeleted = true;
                catch ME_delete
                    app.alert(sprintf('Data successfully backed up, but could not delete the original temporary working file. Error: %s. You may need to delete it manually if you wish to truly start over next time.', ME_delete.message), 'Delete Failed');
                    originalFileDeleted = false;
                    % userSelection is still 'Start Over'. Caller will proceed with empty session
                    % as backup was successful, even if delete failed here.
                end
            end
        end
    else
        % File does not exist, so it's effectively a "Start Over" scenario by default.
        userSelection = 'Start Over';
    end
end
