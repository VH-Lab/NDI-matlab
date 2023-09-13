function res = dataset_metadata(varargin)
%DATASET_METADATA Summary of this function goes here
%   Detailed explanation goes here

disp("dataset_metadata is being called");
res = 0;
if nargin == 1
    disp("opening app");
    a = app1();
    % a = app3v1_4();

else
    vlt.data.assign(varargin{:});
    disp(steps)
    switch (steps)
        case 1
            disp('first step')
            switch (action)
                case 'save'
                    disp(data)
            end
        case 2
            switch (action)
                case 'open'
                    a = app3v1_4();
                case 'save'
                    disp(data)
            end
        case 3
            disp('3rd step')
            switch (action)
                case 'open'
                    a = app2AltView();
                case 'save'
                    disp(data.expApproach);
                    disp(data);
                    res = data;
                case 'submit'
                    disp(data)
                case 'initiate'
                    disp("initiating authors..There are ")
                    numAuthors = str2double(numAuthors);
                    disp(numAuthors + " authors")

                    institutes = cell(1, numAuthors);
                    givenName = cell(1, numAuthors);
                    familyName = cell(1, numAuthors);
                    authorEmail = cell(1, numAuthors);
                    digitalIdentifier = cell(1, numAuthors);
                    additionalDetails = cell(1, numAuthors);
                    authorRole = cell(1, numAuthors);
                    relatedPublications = cell(1, numAuthors);

                    authorArray = cell(1, numAuthors);

                    for i = 1:numAuthors
                        institutes{i} = '';
                        givenName{i} = 'Author';
                        familyName{i} = num2str(i);
                        authorEmail{i} = '';
                        digitalIdentifier{i} = '';
                        additionalDetails{i} = '';
                        authorRole{i} = '';
                        relatedPublications{i} = '';
                        authorArray{i} = sprintf('Author %d', i); % Create author names
                    end
                    disp(authorArray)
                    
                    res = authorArray;
                case 'update institution'
                    authorIdx = str2double(authorIdx);
                    institutes{authorIdx} = updatedInstitutes;
                    res = institutes;
                case 'update given name'
                    authorIdx = str2double(authorIdx);
                    givenName{authorIdx} = updatedGivenName;
                    res = givenName;
                case 'update family name'
                    authorIdx = str2double(authorIdx);
                    familyName{authorIdx} = updatedFamilyName;
                    res = familyName;
                case 'update author Email'
                    authorIdx = str2double(authorIdx);
                    authorEmail{authorIdx} = updatedAuthorEmail;
                    res = authorEmail;
                case 'update digital identifier'
                    authorIdx = str2double(authorIdx);
                    digitalIdentifier{authorIdx} = updatedDigitalIdentifier;
                    res = digitalIdentifier;
                case 'update additional details'
                    authorIdx = str2double(authorIdx);
                    additionalDetails{authorIdx} = updatedAdditionalDetails;
                    res = additionalDetails;
                case 'update author role'
                    authorIdx = str2double(authorIdx);
                    authorRole{authorIdx} = updatedAuthorRole;
                    res = authorRole;
                case 'update related publications'
                    authorIdx = str2double(authorIdx);
                    relatedPublications{authorIdx} = updatedRelatedPublications;
                    res = relatedPublications;

                case 'retrieve'
                    authorIdx = str2double(authorIdx);
                    res = givenName{authorIdx};
    end

    % disp("getting user input...");
    % funding_dir = varargin(1);
    % license = varargin(2);
    % datasetBranchTitle = varargin(3);
    % avstract = varargin(4);
    % comments = varargin(5);
    % 
    % disp(abstract{1});
    % disp(branch{1});
    % disp(license_{1});
end
% fileSelectorInput = app.FileSelector.Value;
% LicenseInput = app.LicenseDropDown.Value;
% datasetBranchTitleInput = app.DatasetBranchTitleEditField.Value;
%             abstractInput = app.AbstractTextArea.Value;
% commentsInput = app.CommentsAdditionalDetailsTextArea.Value;
% ndi.database.fun.dataset_metadata(abstractInput, datasetBranchTitleInput, LicenseInput);

% app.TaskStatusTable.SelectedIndex = 3;
% app.TaskStatusTable.ShowButtonRow = "off"; 
end

