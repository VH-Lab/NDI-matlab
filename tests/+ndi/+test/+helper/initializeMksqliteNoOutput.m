function initializeMksqliteNoOutput()
% initializeMksqliteNoOutput - Capure mksqlite initialization message. 

    % When mksqlite is called for the first time, it drops an initialization
    % message in the command window. This small helper function calls mksqlite 
    % with the 'version sql' input and captures the output to avoid spamming
    % the test log.
    C = evalc( "mksqlite('version sql')" ); %#ok<NASGU>
end
