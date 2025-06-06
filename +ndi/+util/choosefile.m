function [success,filename,replaces] = choosefile(prompt, defaultfilename, dlgtitle, extension_list)
    % ndi.util.choosefile - ask user to choose a file graphically
    %
    % [SUCCESS, FILENAME, REPLACES] = ndi.util.choosefile(PROMPT, DEFAULTFILENAME, DLGTITLE, EXTENSION_LIST)
    %

    success = 0;
    replaces = 0;

    % ask for file name
    dims = [1 50];
    filename = inputdlg(prompt,dlgtitle,dims,defaultfilename);

    if isempty(filename)
        % user selects cancel, return
        success = 0;
        replaces = 0;
        return;
    else
        filename = char(filename);
    end

    % check for existence
    exist = 0;
    for s = extension_list
        if isfile(strcat(filename,char(s)))
            exist = 1;
        end
    end

    while exist
        % while file exists
        promptMessage = sprintf('File exists, do you want to cover?');
        titleBarCaption = 'File existed';
        button = questdlg(promptMessage, titleBarCaption, 'Yes', 'No', 'Yes');
        if strcmpi(button, 'No')
            % user doesn't want to cover, keep asking
            filename = inputdlg(prompt,dlgtitle,dims,defaultfilename);
            if isempty(filename)
                % user selects cancel, return
                success = 0;
                replaces = 0;
                return;
            else
                filename = char(filename);
            end
        else % user chooses to cover, return
            success = 1;
            replaces = 1;
            return;
        end
        % check for existence again, because we got a new filename
        exist = 0;
        for s = extension_list
            if isfile(strcat(filename,char(s)))
                exist = 1;
            end
        end
    end % while

    % gets out from the while loop, which means file does not exist
    % no need to replace
    success = 1;
    replaces = 0;
end % choosefileordir
