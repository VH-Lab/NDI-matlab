package com.ndi;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.util.ArrayList;

import static org.junit.jupiter.api.Assertions.*;

class TableReaderTest {

    @Test
    void loadData() throws IOException {
        TableReader tr = new TableReader(new String[]{"\t", "     "});
        tr.loadData("src/main/resources/sampleTable.txt", "column1", new ArrayList<>());
        Table tb = tr.getTable();
        assertEquals("entry1", tb.getEntry("column1", "entry1"));
        assertEquals("entry2", tb.getEntry("column2", "entry1"));
        assertEquals("entry3", tb.getEntry("column3", "entry1"));
        assertEquals("entry4", tb.getEntry("column1", "entry4"));
        assertEquals("entry5", tb.getEntry("column2", "entry4"));
        assertEquals("entry6", tb.getEntry("column3", "entry4"));
        assertEquals("entry7", tb.getEntry("column1", "entry7"));
        assertEquals("entry8", tb.getEntry("column2", "entry7"));
        assertEquals("entry9", tb.getEntry("column3", "entry7"));
        assertEquals("entry12", tb.getEntry("column1", "entry12"));
        assertEquals("entry2", tb.getEntry("column2", "entry12"));
        assertEquals("entry3", tb.getEntry("column3", "entry12"));
        assertEquals("entry16", tb.getEntry("column1", "entry16"));
        assertEquals(null, tb.getEntry("column2", "entry16"));
        assertEquals("entry6", tb.getEntry("column3", "entry16"));
        assertEquals("entry17", tb.getEntry("column1", "entry17"));
        assertEquals(null, tb.getEntry("column2", "entry17"));
        assertEquals(null, tb.getEntry("column3", "entry17"));
    }
}