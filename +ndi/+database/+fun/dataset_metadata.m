function res = dataset_metadata(varargin)
%DATASET_METADATA Summary of this function goes here
%   Detailed explanation goes here

disp("dataset_metadata is being called");
res = 0;
if nargin == 1
    disp("opening app");
    a = app1();

else
    vlt.data.assign(varargin{:});
    switch (action)
        case 'check'
            
        case 'submit'
            additionalDetails = data.additionalDetails;
            authorRole = data.authorRole;
            relatedPublications = data.relatedPublications;
            
            %% Person document
            custodians ={};
            ppl = {};
            orgs = {};
            afs = {};
            contacts = {};
            for i= 1:data.numAuthors
                disp(i)
                ror = openminds.core.RORID('identifier',data.digitalIdentifier{i});
                org = openminds.core.Organization('digitalIdentifier', ror,...
                    'fullName',data.institutes{i});
                orgs(i) = {org};
                af = openminds.core.Affiliation('memberOf', org);
                afs(i) = {af};
                contact = openminds.core.ContactInformation('email',...
                    data.authorEmail{i});
                contacts(i) = {contact};
                p = openminds.core.Person('familyName',data.familyName{i},'givenName',data.givenName{i},...
                    'affiliation',af, 'contactInformation',contact);
                ppl(i) = {p};
            end
             S = ndi.database.fun.openMINDSobj2struct(ppl);
            treenodes = data.authorRole{1,1};
            for i = 1:numel(treenodes)
                if strcmp(treenodes(i).Text, "Custodian")
                    custodians(end+1) = ppl(i);
                end
            end

            %% Dataset document
            ndiido = ndi.ido();
             % Required = ["identifier", "NDI Cloud"]
              % Required = ["type"]
            % dataset = openminds.core.Dataset('author',ppl,'custodian',custodians,...
            %         'description',data.abstractInput, 'digitalIdentifier',ndiido.identifier, ...
            %         'fullName', data.datasetBranchTitleInput, ...
            %         'hasVersion', "", 'shortName', "");
            
            %% Dataset version
            

        % case 1
        %     disp('first step')
        %     switch (action)
        %         case 'save'
        %             disp(data)
        %     end
        % case 2
        %     switch (action)
        %         case 'open'
        %             a = app3v1_4();
        %         case 'save'
        %             disp(data)
        %             numAuthors = data.numAuthors;
        %             institutes = data.institutes;
        %             givenName = data.givenName;
        %             familyName = data.familyName;
        %             authorEmail = data.authorEmail;
        %             digitalIdentifier = data.digitalIdentifier;
        %             additionalDetails = data.additionalDetails;
        %             authorRole = data.authorRole;
        %             disp(authorRole)
        %             relatedPublications = data.relatedPublications;
        % 
        %             custodian =[];
        %             ppl = [];
        %             orgs =[];
        %             afs = [];
        %             contacts = [];
        %             for i= 1:numAuthors
        %                 disp(i)
        %                 ror = openminds.core.RORID('identifier',digitalIdentifier{i});
        %                 org = openminds.core.Organization('digitalIdentifier', ror,...
        %                     'fullName',institutes{i});
        %                 orgs = [orgs org];
        %                 af = openminds.core.Affiliation('memberOf', org);
        %                 afs = [afs af];
        %                 % orcid = openminds.core.ORCID('identifier',...
        %                 %     'https://orcid.org/0000-0000-0000-0000');
        %                 contact = openminds.core.ContactInformation('email',...
        %                     authorEmail{i});
        %                 contacts = [contacts contact];
        %                 p = openminds.core.Person('familyName',familyName{i},'givenName',givenName{i},...
        %                     'affiliation',af, 'contactInformation',contact);
        %                 ppl =[ppl p];
        %             end
        %             treenodes = authorRole{1,1};
        % 
        %             for i = 1:numel(treenodes)
        %                 if strcmp(treenodes(i).Text, "Custodian")
        %                     isCustodian = true;
        %                     break; % Exit the loop if a "Custodian" node is found
        %                 end
        %             end
        % 
        %             if isCustodian
        %                 disp("There is a 'Custodian' node in the array.");
        %             else
        %                 disp("There is no 'Custodian' node in the array.");
        %             end
        %             disp(ppl)
        % 
        %     end
        % 
        % case 3
        %     disp('3rd step')
        %     switch (action)
        %         case 'open'
        %             a = app2AltView();
        %         case 'save'
        %             disp(data.expApproach);
        %             disp(data);
        %             res = data;
        %         case 'submit'
        %             disp(data)
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

