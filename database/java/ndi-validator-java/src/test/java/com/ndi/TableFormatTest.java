package com.ndi;

import org.json.JSONObject;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class TableFormatTest {

    @Test
    void simpleAddFormat() {
        TableFormat test = new TableFormat().addFormat(new String[]{", ", " ", ", "});
        Map<String, Integer> actual = test.parseColumns("col1, col2 col3, col4");
        Map<String, Integer> expected = new HashMap<String, Integer>(){{
            put("col1", 0);
            put("col2", 1);
            put("col3", 2);
            put("col4", 3);
        }};
        assertEquals(expected, actual);
        ArrayList<String> actual2 = test.parseLine("entry1, entry2 entry3, entry4");
        ArrayList<String> expected2 = new ArrayList<>(Arrays.asList("entry1", "entry2", "entry3", "entry4"));
        assertEquals(expected2, actual2);
        actual2 = test.parseLine(",  , ");
        expected2 = new ArrayList<String>(Arrays.asList(null,null,null,null));
        assertEquals(expected2, actual2);
        test.addEntryPattern(0, "$");
        test.addEntryPattern(3, "*");
        assertEquals(new HashSet<>(Arrays.asList("a", "b", "c", "d")), test.parseEntry("a$b$c$d", 0));
        assertEquals(new HashSet<>(Arrays.asList("a", "b", "c", "d")), test.parseEntry("a*b*c*d", 3));
        assertEquals(new HashSet<>(Collections.singletonList("abcd")), test.parseEntry("abcd", 3));
    }

    @Test
    void invalidAddFormat(){
        TableFormat test = new TableFormat();
        try{
            test.addFormat(null);
            fail();
        }
        catch (IllegalArgumentException ex){
            assertEquals("TableFormat Error: format must be greater than 1 and you can't add more format on the top of the existing list of split formats", ex.getMessage());
        }
        try{
            test.addFormat(new String[]{});
            fail();
        }
        catch (IllegalArgumentException ex){
            assertEquals("TableFormat Error: format must be greater than 1 and you can't add more format on the top of the existing list of split formats", ex.getMessage());
        }
        try{
            test.addFormat(new String[]{" : ", " : ", " : "});
            test.addFormat(new String[]{",", ","});
            fail();
        }
        catch (IllegalArgumentException ex){
            assertEquals("TableFormat Error: format must be greater than 1 and you can't add more format on the top of the existing list of split formats", ex.getMessage());
        }
        try{
            test.addEntryPattern(-1, "$");
            fail();
        }
        catch (IllegalArgumentException ex){
            assertEquals("TableFormat Error: cannot add an entry pattern to an non-existing column", ex.getMessage());
        }
        try{
            test.addEntryPattern(4, "$");
            fail();
        }
        catch (IllegalArgumentException ex){
            assertEquals("TableFormat Error: cannot add an entry pattern to an non-existing column", ex.getMessage());
        }
    }

    @Test
    void testInvalidOperation(){
        TableFormat test = new TableFormat();
        try{
            test.parseColumns("invalid input");
            fail();
        }
        catch(IllegalStateException ex){
            assertEquals("TableFormat Error: patterns has not yet been initialized", ex.getMessage());
        }
        try{
            test.parseLine("invalid input");
            fail();
        }
        catch(IllegalStateException ex){
            assertEquals("TableFormat Error: patterns has not yet been initialized", ex.getMessage());
        }
        try{
            test.parseEntry("invalid input", 0);
            fail();
        }
        catch(IllegalStateException ex){
            assertEquals("TableFormat Error: patterns has not yet been initialized", ex.getMessage());
        }
        test = test.addFormat(new String[]{", ", " ", ", "});
        test.addEntryPattern(0, "$");
        try{
            test.parseEntry("invalid$entry",4);
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("TableFormat Error: your index is out of bound, index expected to be in between 0 and 3", ex.getMessage());
        }
    }

    @Test
    void testJSONInitialization(){
        JSONObject sample = new JSONObject("{\n" +
                "   'format' : [' ', ' ', ' '], \n" +
                "   'entryFormat' : [null, null, null, '#']\n" +
                "}");
        TableFormat test = TableFormat.buildFromJSON(sample);
        assertEquals(new HashMap<String, Integer>()
                {{
                    put("col1", 0);
                    put("col2", 1);
                    put("col3", 2);
                    put("col4", 3);
                }}
        , test.parseColumns("col1 col2 col3 col4"));
        assertEquals(Arrays.asList("entry1", "entry2", "entry3", null),test.parseLine("entry1 entry2 entry3 "));
        assertEquals(new HashSet<>(Arrays.asList("one", "two", "three")), test.parseEntry("one#two#three#",3));
        assertNull(test.parseEntry("one$two$three$", 0));
        assertNull(test.parseEntry("one$two$three$", 1));
        assertNull(test.parseEntry("one$two$three$", 2));
    }
}