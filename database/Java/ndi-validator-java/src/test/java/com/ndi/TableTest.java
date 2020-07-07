package com.ndi;

import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.Arrays;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

class TableTest {

    @Test
    void badConstructor(){
        try{
            Table tb = new Table(new ArrayList<>(Arrays.asList("col1", "col2", "col3", "col4")), "col0");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("Your primary index must be one of the columns", ex.getMessage());
        }
        try{
            Table tb = new Table(new ArrayList<>(Arrays.asList()), "");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("Your table must have at least one column", ex.getMessage());
        }
    }

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
        try{
            tb.addRow(new ArrayList<>(Arrays.asList("1", "2", "3", "4", "5", "6")));
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

    @Test
    void createDuplicateIndex(){
        Table tb = new Table(new ArrayList<>(Arrays.asList("col1", "col2", "col3")), "col1");
        tb.addRow(new ArrayList<>(Arrays.asList("entry1", "entry2", "entry3")));
        tb.addRow(new ArrayList<>(Arrays.asList("entry4", "entry2", "entry5")));
        tb.addRow(new ArrayList<>(Arrays.asList("entry5", "entry3", "entry3")));
        tb.createIndex("col2");
        assertEquals(new ArrayList<>(Arrays.asList("entry1", "entry4")),
                tb.getEntry("col1", "entry2", "col2"));
        assertEquals(new ArrayList<>(Arrays.asList("entry5")),
                tb.getEntry("col1", "entry3", "col2"));
        assertEquals(new ArrayList<>(Arrays.asList("entry1", "entry5")),
                tb.getEntry("col1", "entry3", "col3"));
        assertEquals(new ArrayList<>(Arrays.asList("entry4")),
                tb.getEntry("col1", "entry5", "col3"));
        try{
            tb.createIndex("col5");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("Attempt to create on index that does not exist", ex.getMessage());
        }
        try{
            tb.getEntry("col1", "entry5", "col5");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("Key does not exist", ex.getMessage());
        }
    }

    @Test
    void testSecondaryIndex(){
        Table tb = new Table(new ArrayList<>(Arrays.asList("col1", "col2", "col3")), "col1");
        tb.addRow(new ArrayList<>(Arrays.asList("entry1", "entry2", "entry3")));
        tb.addRow(new ArrayList<>(Arrays.asList("entry4", "entry5", "entry6")));
        tb.addRow(new ArrayList<>(Arrays.asList("entry7", "entry8", "entry9")));
        assertEquals(new ArrayList<>(Arrays.asList("entry1")), tb.getEntry("col1", "entry3", "col3"));
        assertEquals(new ArrayList<>(Arrays.asList("entry3")), tb.getEntry("col3", "entry2", "col2"));
        assertTrue(tb.isSecondaryRowKey("entry2", "col2"));
        assertTrue(tb.isSecondaryRowKey("entry9", "col3"));
        assertFalse(tb.isSecondaryRowKey("entry7", "col1"));
        assertTrue(tb.isRowKey("entry7"));
        assertTrue(tb.isColKey("col1") && tb.isColKey("col2") && tb.isColKey("col3"));
        tb.addRow(new ArrayList<>(Arrays.asList("entry10", "entry11", "entry12")));
        assertEquals(new ArrayList<>(Arrays.asList("entry10")), tb.getEntry("col1", "entry11", "col2"));
        assertEquals("entry11", tb.getEntry("col2", "entry10"));
        assertEquals(new ArrayList<>(Arrays.asList("entry10")), tb.getEntry("col1", "entry12", "col3"));
    }

    @Test
    void IllegalQuery(){
        Table tb = new Table(new ArrayList<>(Arrays.asList("col1", "col2", "col3")), "col2");
        tb.addRow(new ArrayList<>(Arrays.asList("entry1", "entry2", "entry3")));
        tb.addRow(new ArrayList<>(Arrays.asList("entry4", "entry5", "entry6")));
        tb.addRow(new ArrayList<>(Arrays.asList("entry7", "entry8", "entry9")));
        try{
            tb.getEntry("col4", "entry5");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("Key does not exist", ex.getMessage());
        }
        try{
            tb.getEntry("col1", "entry4");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("Key does not exist", ex.getMessage());
        }
        try{
            tb.createIndex("col9");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("Attempt to create on index that does not exist", ex.getMessage());
        }
        tb.createIndex("col1");
        try{
            tb.getEntry("col1", "entry2", "col1");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("Key does not exist", ex.getMessage());
        }
        try{
            tb.getEntry("col1", "entry3", "col1");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("Key does not exist", ex.getMessage());
        }
    }

}