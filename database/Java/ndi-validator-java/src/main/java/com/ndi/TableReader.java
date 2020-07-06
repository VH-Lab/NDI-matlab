package com.ndi;

import java.io.BufferedReader;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.ObjectOutputStream;
import java.util.List;
import java.util.ArrayList;

/**
 * This class is primarily used to create valid binary file that the Validator can load.
 */
public class TableReader {
    private String[] format;
    private Table table;

    /**
     * Create a new instance of TableReader
     *
     * @param format    An array specifying how the text file split each columns of the table
     *                  For instance, for a text file : "entry1\tentry2\tentry3\tentry4",format
     *                  needs to be String[]{"\t", "\t", "\t"}. Also format.length needs to be
     *                  exactly one less than the number of columns, or an IllegalArgumentException
     *                  will be thrown when we try to read the table
     */
    public TableReader(String[] format){
        this.format = format;
    }

    /**
     * The setter for the format field
     *
     * @param format    An array specifying how the text file split each columns of the table.
     *                  See the constructor javadoc for more detailed explanation
     */
    public void setFormat(String[] format){
        this.format = format;
    }

    /**
     * The getter method for the table field. An IllegalStateException will be thrown
     * if the table has not be instantiated.
     */
    public Table getTable(){
        if (this.table == null){
            throw new IllegalStateException("You have not load the data yet");
        }
        else{
            return this.table;
        }
    }

    /**
     * Read the text file from the given file path, then convert it into an instance of Table
     * object, which can be saved to a specified directory later through calling the saveTo
     * method. This methods assumes that the row of the columns are split by a new line, and
     * the first row should specify the column names. Also make sure that each entry does not
     * contain any character that you use to split each entry in the row, or else the behavior
     * may be undefined
     *
     * @param filepath  the given filepath
     */
    public void loadData(String filepath, String primaryIndex, List<String> secondaryIndices) throws IOException{
        try(BufferedReader reader = new BufferedReader(new FileReader(filepath))){
            String line = reader.readLine();
            this.table = new Table(parseLine(line), primaryIndex);
            for (String secondaryIndex : secondaryIndices){
                table.createIndex(secondaryIndex);
            }
            while (line != null){
                table.addRow(parseLine(line));
                line = reader.readLine();
            }
        }
    }

    /**
     * Split the line of text into an ArrayList of string, using the specified format
     * specified by the user
     *
     * @param input the line of string we want to split
     * @return      a ArrayList of string being split using the given format
     */
    private ArrayList<String> parseLine(String input){
        ArrayList<String> output = new ArrayList<>();
        String res = input;
        for (String pattern : this.format){
            int location = res.indexOf(pattern);
            if (location == -1){
                throw new IllegalArgumentException("Pattern cannot be found");
            }
            String tobeAdded = res.substring(0, location);
            if (tobeAdded.equals("")){
                output.add(null);
            }
            else{
                output.add(res.substring(0, location));
            }
            if (location + format.length <= input.length())
                res = res.substring(location + pattern.length());
        }
        if (res.equals("")){
            output.add(null);
        }
        else{
            output.add(res);
        }
        return output;
    }

    /**
     * Save the instance of the instance of table object that has just been
     * created and store it as a binary file into the specified directory.
     * A IllegalStateException will be thrown if the table has not been instantiated.
     * That is, this.loadData() has be called before we can serialize the table
     * object into the binary file format successfully.
     *
     * @param filepath      the file directory to save to
     */
    public void saveTo(String filepath) throws IOException{
        if (table != null){
            try (FileOutputStream fileOut   = new FileOutputStream(filepath);
                 ObjectOutputStream out     = new ObjectOutputStream(fileOut)){
                    out.writeObject(this.table);
                    out.close();
                    fileOut.close();
                    System.out.println("file has been successfully saved to " + filepath);
            }
        }
        else{
            throw new IllegalStateException("Your table is empty");
        }
    }

    public static void main(String[] args) throws IOException, ClassNotFoundException{
        TableReader tr = new TableReader(new String[]{"\t", "\t", "\t"});
        tr.loadData("src/main/resources/GenBankControlledVocabulary.tsv", "Scientific_Name", new ArrayList<>());
        Table tb = tr.getTable();
        /*
        try (ObjectInputStream in = new ObjectInputStream(new FileInputStream("src/main/resources/GenBankControlledVocabulary.bin"))){
            tb = (Table)in.readObject();
        }
         */
        System.out.println("Done");
        System.out.println(tb.getEntry("Synonyms", "Acantharctus delfini"));
    }
}
