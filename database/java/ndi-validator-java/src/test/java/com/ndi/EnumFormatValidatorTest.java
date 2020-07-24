package com.ndi;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.util.Arrays;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

class EnumFormatValidatorTest {

    @Test
    void buildFromJSON() {

    }

    @Test
    void testInvalidBuilder(){
        EnumFormatValidator.Builder builder = new EnumFormatValidator.Builder();
        try{
            builder.setFormatTag(null);
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("EnumFormatValidator Initialization Error: formatName cannot be null", ex.getMessage());
        }
        try{
            builder.setRules(null);
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("EnumFormatValidator Initialization Error: Rules cannot be null", ex.getMessage());
        }
        try{
            builder.setRules(new Rules());
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("EnumFormatValidator Initialization Error: You must have at least one column, whose entry will be accepted by the validator", ex.getMessage());
        }
        try{
            builder.setFilePath(null);
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("EnumFormatValidator Initialization Error: filePath cannot be null", ex.getMessage());
        }
        try{
            builder.setFilePath("src/test/java/com/ndi/invalid_test.json");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("EnumFormatValidator Initialization Error: file does not exists", ex.getMessage());
            builder.setFilePath("src/main/resources/test.json");
        }
    }

    @Test
    void testLoadData(){
        EnumFormatValidator test = new EnumFormatValidator.Builder()
                    .setFilePath("src/main/resources/test.txt")
                    .setRules(new Rules().addExpectedColumn("col1").addSuggestedColumn(Arrays.asList("col3", "col4")))
                    .setFormatTag("test")
                    .setTableFormat(new TableFormat().addFormat(new String[]{", ", ", ", ", "}).addEntryPattern(2, ":"))
                    .loadData().build();
        assertEquals(test.validate("entry1"), Optional.empty());
        assertEquals(test.validate("entry5"), Optional.empty());
        assertEquals(test.validate("entry6"), Optional.empty());
        assertEquals(test.validate("entry2"), Optional.of("Entered: " + "entry2" + ". Expected: an entry from the columns " + "[col1]"));
        assertEquals(test.validate("entry7"), Optional.of("Entered: " + "entry7" + ". Expected: an entry from the columns " + "[col1]"));
        assertEquals(test.validate("entry3"), Optional.of("Entered: " + "entry3" + ". Expected: any one of " + "[entry5]"));
        assertEquals(test.validate("entry8"), Optional.of("Entered: " + "entry8" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry9"), Optional.of("Entered: " + "entry9" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry10"), Optional.of("Entered: " + "entry10" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry4"), Optional.of("Entered: " + "entry4" + ". Expected: any one of " + "[entry1]"));
        assertEquals(test.validate("entry12"), Optional.of("Entered: " + "entry12" + ". Expected: any one of " + "[entry5]"));
        assertEquals(test.validate("entry11"), Optional.of("Entered: " + "entry11" + ". Expected: any one of " + "[entry6]"));

        test = new EnumFormatValidator.Builder()
                .setFilePath("src/main/resources/test.txt.gz")
                .setRules(new Rules().addExpectedColumn("col1").addSuggestedColumn(Arrays.asList("col3", "col4")))
                .setFormatTag("test")
                .setTableFormat(new TableFormat().addFormat(new String[]{", ", ", ", ", "}).addEntryPattern(2, ":"))
                .loadDataGzip().build();
        assertEquals(test.validate("entry1"), Optional.empty());
        assertEquals(test.validate("entry5"), Optional.empty());
        assertEquals(test.validate("entry6"), Optional.empty());
        assertEquals(test.validate("entry2"), Optional.of("Entered: " + "entry2" + ". Expected: an entry from the columns " + "[col1]"));
        assertEquals(test.validate("entry7"), Optional.of("Entered: " + "entry7" + ". Expected: an entry from the columns " + "[col1]"));
        assertEquals(test.validate("entry3"), Optional.of("Entered: " + "entry3" + ". Expected: any one of " + "[entry5]"));
        assertEquals(test.validate("entry8"), Optional.of("Entered: " + "entry8" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry9"), Optional.of("Entered: " + "entry9" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry10"), Optional.of("Entered: " + "entry10" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry4"), Optional.of("Entered: " + "entry4" + ". Expected: any one of " + "[entry1]"));
        assertEquals(test.validate("entry12"), Optional.of("Entered: " + "entry12" + ". Expected: any one of " + "[entry5]"));
        assertEquals(test.validate("entry11"), Optional.of("Entered: " + "entry11" + ". Expected: any one of " + "[entry6]"));

        test = new EnumFormatValidator.Builder()
                .setFilePath("src/main/resources/test.txt.gz")
                .setRules(new Rules().addExpectedColumn("col1").addSuggestedColumn(Arrays.asList("col3", "col4")))
                .setFormatTag("test")
                .setTableFormat(new TableFormat().addFormat(new String[]{", ", ", ", ", "}).addEntryPattern(2, ":"))
                .build();
        assertEquals(test.validate("entry1"), Optional.empty());
        assertEquals(test.validate("entry5"), Optional.empty());
        assertEquals(test.validate("entry6"), Optional.empty());
        assertEquals(test.validate("entry2"), Optional.of("Entered: " + "entry2" + ". Expected: an entry from the columns " + "[col1]"));
        assertEquals(test.validate("entry7"), Optional.of("Entered: " + "entry7" + ". Expected: an entry from the columns " + "[col1]"));
        assertEquals(test.validate("entry3"), Optional.of("Entered: " + "entry3" + ". Expected: any one of " + "[entry5]"));
        assertEquals(test.validate("entry8"), Optional.of("Entered: " + "entry8" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry9"), Optional.of("Entered: " + "entry9" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry10"), Optional.of("Entered: " + "entry10" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry4"), Optional.of("Entered: " + "entry4" + ". Expected: any one of " + "[entry1]"));
        assertEquals(test.validate("entry12"), Optional.of("Entered: " + "entry12" + ". Expected: any one of " + "[entry5]"));
        assertEquals(test.validate("entry11"), Optional.of("Entered: " + "entry11" + ". Expected: any one of " + "[entry6]"));
    }
}