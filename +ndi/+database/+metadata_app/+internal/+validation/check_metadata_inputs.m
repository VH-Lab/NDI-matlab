function [submit, errorStep] = check_metadata_inputs(app)
% CHECK_METADATA_INPUTS - Check metadata entered in the Metadata Editor

% Note: 
%   - This function is not used. 
%   - It is also very out of date
%   - However, it could serve as a blueprint for a function to validate
%     metadata entered in the MetadataEditorApp

    fig = app.UIFigure;
    ud = fig.UserData;
    submit = true;
    msg = {};
    errorStep = {{''}, {''}, {''}};
    if ~isfield(ud, 'abstractInput')
        % Show the warning sign
        app.EmptyAbstractWarning.Visible = 'on';
        % app.TabGroup.SelectedTab = app.Tab1;
        app.EmptyAbstractWarning.Tooltip = "Abstract is missing";
        msg{end+1} = {"Abstract is missing"};
        submit = false;
        errorStep{1} = 1;
    end
    % else
    %     app.LabelWarning.Visible = 'off';
    if ~isfield(ud, 'datasetBranchTitleInput')
        % Show the warning sign
        app.EmptyBranchTitleWarning.Visible = 'on';
        app.EmptyBranchTitleWarning.Tooltip = "Dataset branch title is missing";
        msg{end+1} = {"Dataset branch title is missing"};
        submit = false;
        errorStep{1} = 1;
    end

    if ~isfield(ud, 'numAuthors')
        app.EmptyAuthorWarning.Visible = 'on';
        app.EmptyAuthorWarning.Tooltip = "Please add an author";
        msg{end+1} = {"Please add an author"};
        submit = false;
        errorStep{2} = 2;
    else
        if ud.numAuthors <= 0
            app.EmptyAuthorWarning.Visible = 'on';
            app.EmptyAuthorWarning.Tooltip = "Please add an author";
            msg{end+1} = {"Please add an author"};
            submit = false;
            errorStep{2} = 2;
        end
        for i = 1 : ud.numAuthors
            if isempty(ud.institutes{i})
                app.EmptyInstituteWarning.Visible = 'on';
                errmsg = sprintf('Please fill in the institute for author %d', i);
                app.EmptyInstituteWarning.Tooltip = errmsg;
                errorStep{2} = 2;
            else
                rorPattern = '^https://ror.org/0([0-9]|[^ILO]|[a-z]){6}[0-9]{2}$';
                match = regexp(ud.institutes{i}, rorPattern, 'match');
                if isempty(match{1})
                    app.EmptyInstituteWarning.Visible = 'on';
                    errmsg = sprintf(['Please fill in a valid ROR ID for author %d. ' ...
                        'The allowed form of a ROR identifier is the entire URL: https://ror.org/02mhbdp94.'], i);
                    app.EmptyInstituteWarning.Tooltip = errmsg;
                    errorStep{2} = 2;
                    continue;
                end
                institutes = ud.institutes{i};
                cmd = sprintf("curl https://api.ror.org/organizations/%s", institutes{1});
                [~, response] = system(cmd);
                response = jsondecode(response);
                if isfield(response, "errors")
                    app.EmptyInstituteWarning.Visible = 'on';
                    errmsg = sprintf('%s. Please fill in a valid ROR ID for author %d', response.errors{1}, i);
                    app.EmptyInstituteWarning.Tooltip = errmsg;
                    errorStep{2} = 2;
                end
            end

            if isempty(ud.givenName{i})
                app.EmptyGivenNameWarning.Visible = 'on';
                errmsg = sprintf('Please fill in the given name for author %d', i);
                app.EmptyGivenNameWarning.Tooltip = errmsg;
                errorStep{2} = 2;
            end
            if isempty(ud.familyName{i})
                app.EmptyFamilyNameWarning.Visible = 'on';
                errmsg = sprintf('Please fill in the family name for author %d', i);
                app.EmptyFamilyNameWarning.Tooltip = errmsg;
                errorStep{2} = 2;
            end
            if isempty(ud.authorEmail{i})

                app.EmptyEmailWarning.Visible = 'on';
                errmsg = sprintf('Please fill in the Email for author %d', i);
                app.EmptyEmailWarning.Tooltip = errmsg;
                errorStep{2} = 2;
            else
                emailPattern = "^\S+@\S+$";
                match = regexp(ud.authorEmail{i}, emailPattern, 'match');
                disp(match)
                if isempty(match)
                    app.EmptyEmailWarning.Visible = 'on';
                    errmsg = sprintf('Please fill in a valid Email for author %d. ', i);
                    app.EmptyEmailWarning.Tooltip = errmsg;
                    errorStep{2} = 2;
                    continue;
                end
            end
            if isempty(ud.digitalIdentifier{i})
                app.EmptyDigitalIdentifierWarning.Visible = 'on';
                errmsg = sprintf('Please fill in the digital identifier for author %d', i);
                app.EmptyDigitalIdentifierWarning.Tooltip = errmsg;
                errorStep{2} = 2;
            end
            if isempty(ud.relatedPublications{i})
                app.EmptyRelatedPublicationsWarning.Visible = 'on';
                errmsg = sprintf('Please fill in the related publications for author %d', i);
                app.EmptyRelatedPublicationsWarning.Tooltip = errmsg;
                errorStep{2} = 2;
            end
        end
    end

    if ~isfield(ud, 'dataType') || isempty(find(ud.dataType == 1, 1))
        app.EmptyDataTypeWarning.Visible = 'on';
        app.EmptyDataTypeWarning.Tooltip = "Please select data type";
        msg{end+1} = {"Please select data type"};
        submit = false;
        errorStep{3} = 3;
    end
    if ~isfield(ud, 'fullDocumentation') || isempty(ud.fullDocumentation)
        app.EmptyFullDocumentationWarning.Visible = 'on';
        app.EmptyFullDocumentationWarning.Tooltip = "Please input the full documentation";
        msg{end+1} = {"Please input the full documentation"};
        submit = false;
        errorStep{3} = 3;
    end
    if ~isfield(ud, 'releaseDate') || isempty(ud.fullDocumentation)
        app.EmptyReleaseDateWarning.Visible = 'on';
        app.EmptyReleaseDateWarning.Tooltip = "Please select a release date";
        msg{end+1} = {"Please select a release date"};
        submit = false;
        errorStep{3} = 3;
    end
    if ~isfield(ud, 'techApproach') || isempty(ud.techApproach)
        app.EmptyTechEmployedWarning.Visible = 'on';
        app.EmptyTechEmployedWarning.Tooltip = "Please select the techniques employed";
        msg{end+1} = {"Please select the techniques employed"};
        submit = false;
        errorStep{3} = 3;
    end
    if ~isfield(ud, 'expApproach') || isempty(ud.expApproach)
        app.EmptyExpApproachWarning.Visible = 'on';
        app.EmptyExpApproachWarning.Tooltip = "Please select the experimental approach";
        msg{end+1} = {"Please select the experimental approach"};
        submit = false;
        errorStep{3} = 3;
    end
    if ~isfield(ud, 'versionInnovation') || isempty(ud.versionInnovation)
        app.EmptyVersionInnovationWarning.Visible = 'on';
        app.EmptyVersionInnovationWarning.Tooltip = "Please input the version innovation";
        msg{end+1} = {"Please input the version innovation"};
        submit = false;
        errorStep{3} = 3;
    end
    disp(msg)

    msg = cell(1,3);
    state = 1;

    %% DigitalIdentifier
    % digitalIdentifierPattern = '^https://ror.org/0([0-9]|[^ILO]|[a-z]){6}[0-9]{2}$';
    % for i = 1:numAuthors
    %     match = regexp(digitalIdentifier{i}, digitalIdentifierPattern, 'match');
    %     if isempty(match)
    %         err.digitalIdentifier = "Digital Identifier is invalid.";
    %         err.numAuthors = i;
    %         msg{2} = "Wrong input for step 2";
    %         state = 0;
    %     end
    % end

    %% email
    % emailPattern = "(?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/";

    %%
