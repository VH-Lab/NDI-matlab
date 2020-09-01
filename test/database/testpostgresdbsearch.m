disp('=========== SEARCH TEST =======');
mypostgresdb = ndi_postgresdb("matthewgonzalgo","matthewgonzalgo","");
mypostgresdb.db.Message

%remove(mypostgresdb, 'ba694083b2804052825cc2f0400cc1a2', '')

field = 'different2'
search_command = 'or'
param1 = ["data","Gemini","Apollo";
       "Skylab",]
param2 = ''
q1 = ndi_query(field, search_command, param1, param2);
s1 = search(mypostgresdb, q1)

close(mypostgresdb.db)
disp('=========== SEARCH TEST DONE =======');