function create_new_database
    % c = uicontrol('Style','edit');
    % c.Callback = @userInput;
    %     function userInput(src, event)
    %         val = c.String;
    %         disp(['input: ' val]);
    %     end

    prompt = {'Are you adding a document to an existing dataset? y/n'};
    dlgtitle = 'dataset id';
    dims = [1 40];
    definput = {'y'};
    opts.Interpreter = 'tex';
    answer = inputdlg(prompt,dlgtitle,dims,definput,opts);
    answer = answer{1,1};
    disp(answer);
    if answer == 'y'
        prompt = {'Please enter your dataset id'};
        dlgtitle = 'dataset id';
        dims = [1 40];
        definput = {'y'};
        opts.Interpreter = 'tex';
        answer = inputdlg(prompt,dlgtitle,dims,definput,opts);
        answer = answer{1,1};
    end
end
