package com.ndi;

import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.Arrays;

import static org.junit.jupiter.api.Assertions.*;

class TableTest {

    @Test
    void basicAddRow() {
        ArrayList<String> cols = new ArrayList<>(Arrays.asList("col1", "col2", "col3", "col4"));
        ArrayList<String> row1 = new ArrayList<>(Arrays.asList("entry1", "entry2", "entry3", "entry4"));
        ArrayList<String> row2 = new ArrayList<>(Arrays.asList("entry5", "entry6", "entry7", "entry8"));
        ArrayList<String> row3 = new ArrayList<>(Arrays.asList(null, null, "entry10", "entry8"));
        Table tb = new Table(cols, "col3");
        tb.addRow(row1);
        tb.addRow(row2);
        tb.addRow(row3);

        //testing with key
        assertEquals("entry1", tb.getEntry("col1", "entry3"));
        assertEquals("entry2", tb.getEntry("col2", "entry3"));
        assertEquals("entry3", tb.getEntry("col3", "entry3"));
        assertEquals("entry4", tb.getEntry("col4", "entry3"));
        assertEquals("entry5", tb.getEntry("col1", "entry7"));
        assertEquals("entry6", tb.getEntry("col2", "entry7"));
        assertEquals("entry7", tb.getEntry("col3", "entry7"));
        assertEquals("entry8", tb.getEntry("col4", "entry7"));
        assertNull(tb.getEntry("col1", "entry10"));
        assertNull(tb.getEntry("col2", "entry10"));
        assertEquals("entry10", tb.getEntry("col3", "entry10"));
        assertEquals("entry8", tb.getEntry("col4", "entry10"));

        //testing with index
        assertEquals("entry1", tb.getEntry(0, 0));
        assertEquals("entry2", tb.getEntry(1, 0));
        assertEquals("entry5", tb.getEntry(0, 1));
        assertNull(tb.getEntry(1, 2));
        assertEquals("entry6", tb.getEntry(1, 1));
        assertEquals("entry7", tb.getEntry(2, 1));
        assertEquals("entry3", tb.getEntry(2, 0));
        assertEquals("entry4", tb.getEntry(3, 0));
        assertEquals("entry8", tb.getEntry(3, 1));
        assertEquals("entry10", tb.getEntry(2, 2));
        assertNull(tb.getEntry(0, 2));
        assertEquals("entry8", tb.getEntry(3, 2));
    }

    @Test
    void illegalAddRow(){
        ArrayList<String> cols = new ArrayList<>(Arrays.asList("col1", "col2", "col3", "col4"));
        Table tb = new Table(cols, "col2");
        ArrayList<String> row1Illegal = new ArrayList<>(Arrays.asList("entry1", null, "entry3", "entry4"));
        ArrayList<String> row1Legal = new ArrayList<>(Arrays.asList("entry1", "entry2", "entry3", "entry4"));
        ArrayList<String> row2Illegal = new ArrayList<>(Arrays.asList("entry1", "entry2", "entry3", "entry4"));
        ArrayList<String> row2Legal = new ArrayList<>(Arrays.asList("entry1", "entry5", "entry5", "entry4"));
        ArrayList<String> row3Illegal = new ArrayList<>(Arrays.asList("entry1", "entry5", "entry4"));
        try{
            tb.addRow(row1Illegal);
            fail();
        }
        catch (IllegalArgumentException ex){
            assertEquals("the primary index cannot be null", ex.getMessage());
            tb.addRow(row1Legal);
        }
        try{
            tb.addRow(row2Illegal);
            fail();
        }
        catch (IllegalArgumentException ex){
            assertEquals("the primary index has to be unique", ex.getMessage());
            tb.addRow(row2Legal);
        }
        try{
            tb.addRow(row3Illegal);
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("tuple size must match with the size of the column", ex.getMessage());
        }
        assertEquals("entry1", tb.getEntry("col1", "entry2"));
        assertEquals("entry2", tb.getEntry("col2", "entry2"));
        assertEquals("entry3", tb.getEntry("col3", "entry2"));
        assertEquals("entry4", tb.getEntry("col4", "entry2"));
        assertEquals("entry1", tb.getEntry("col1", "entry5"));
        assertEquals("entry5", tb.getEntry("col2", "entry5"));
        assertEquals("entry5", tb.getEntry("col3", "entry5"));
        assertEquals("entry4", tb.getEntry("col4", "entry5"));
    }
}