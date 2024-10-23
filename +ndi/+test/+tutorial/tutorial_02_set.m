function tutorial_02_set()
    % ndi.test.tutorial.tutorial_02_set - run the Tutorial 2.* test set
    %
    % ndi.test.tutorial.tutorial_02_set
    %
    % Runs the code for Tutorial 2.1, 2.2, 2.3, 2.4, and 2.5.
    %
    % This function requires that a clean copy of the test data
    % 'ts_exper1' and and 'ts_exper2' be installed at
    %
    % [userpath filesep 'Documents' filesep 'NDI filesep 'Test']
    %
    % Note that one must make the directory 'Test' manually. The files must be unzipped.
    % 'ts_exper1' is available at
    %   https://drive.google.com/file/d/1j7IAeMSrH64-qIDLB5EJYUofJSdinwuU/view?usp=sharing
    % and 'ts_exper2' is available at
    %   https://drive.google.com/file/d/1otNMkVgZ6KBIn2Y-W2oYVj2DgSOgV-xE/view?usp=sharing
    % 'ts_exper2' updated for the new database (2023-04) is here:
    %   https://drive.google.com/file/d/1D756b6_n6f0wrBqN4cJOuHOs_46YN_xy/view?usp=sharing
    %
    %
    % Note that this function requires some user intervention.
    % For the purpose of the test, one can simply choose Kmeans clustering
    % with 1 cluster, press the cluster button, and mark the cluster as "Excellent"
    % quality.
    %
    %

    ndi.example.tutorial.tutorial_02_01([],1);

    ndi.example.tutorial.tutorial_02_02([],1);
    ndi.example.tutorial.tutorial_02_03([],1);
    ndi.example.tutorial.tutorial_02_04([],1);
    ndi.example.tutorial.tutorial_02_05([],1);


    disp(['If you are reading this line, all tutorial parts executed successfully.']);
