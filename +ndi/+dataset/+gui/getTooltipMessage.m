function msg = getTooltipMessage(keyword)
% getTooltipMessage - Returns a tooltip / help message for a given keyword


switch keyword
    
% % Folder organization page

    case 'Select subfolder example'
        msg = {'Select a subfolder from the list to use as an example', ...
            'for the folder hierarchy which your data is organized after.'};
        
    case 'Set subfolder type'
        msg = {'Choose which type the selected subfolder is'};

    case 'Exclusion list'
        msg = {'Enter a word or a comma-separated list of words to ignore.\n', ...
            '\nAll folders containing one or more words in this list', ...
            'will be excluded from the list of detected folders.\n', ...
            '\nNote: Each input row corresponds to a subfolder level'};
        
    case 'Inclusion list'
        msg = {'Enter a word/expression to only include folders matching', ...
            'that word/expression.\n', ...
            '\nThe expression can contain the wildcard (*) character,'...
            'and the # symbol can be used to substitute numbers. See', ...
            'matlab''s regexp function for a complete overview of valid', ...
            'expressions.\n', ...
            '\nExample: If a folder is named "session_123_training"', ...
            'the expression could be session_###. In that case, only', ...
            'folders containing the word session followed by three numbers', ...
            'will be included in the detected folder list.'};
        
% % DAQ Systems page

    case 'Select Data Source'
        msg = "Select a DAQ system that was used for data collection";

    case 'Select Data Reader'
        msg = "Select a class / interface to use for reading data";

    case 'File Parameters'
        msg = {'Enter all file parameters (as a comma separated list)', ...
               'that are needed for this DAQ System.\n', ...
               '\nNote: You can enter any regexp expression'};

    otherwise
        msg = 'No help available yet';
end

if isa(msg, 'cell')
    msg = strjoin(msg, ' ');
end

msg = sprintf(msg);


end

