package com.ndi;

import org.junit.jupiter.api.Test;

import java.util.*;

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
        assertEquals(new HashSet<>(Arrays.asList("a", "b", "c", "d")), test.parseEntry("a$b$c$d", 0));
    }
}