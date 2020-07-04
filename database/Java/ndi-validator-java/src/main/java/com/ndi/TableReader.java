package com.ndi;

import java.io.FileOutputStream;
import java.io.IOException;
import java.io.ObjectOutputStream;

public class TableReader {
    private int numOfCol;
    private int numOfRow;
    private String[] format;
    private Table table;

    /**
     *
     * @param numOfCol
     * @param numOfRow
     * @param format
     */
    public TableReader(int numOfCol, int numOfRow, String[] format){
        if (numOfCol-1 != format.length){
            throw new IllegalArgumentException("the size of format must match with the number of columns");
        }
        this.numOfCol = numOfCol;
        this.numOfRow = numOfRow;
        this.format = format;
    }

    /**
     *
     * @param numOfCol
     * @param numOfRow
     */
    public TableReader(int numOfCol, int numOfRow){
        this.numOfCol = numOfCol;
        this.numOfRow = numOfRow;
        String[] defaultFormat = new String[numOfCol];
        for (int i = 0; i < numOfCol-1; i++){
            defaultFormat[i] = "    ";
        }
        this.format = defaultFormat;
    }

    /**
     *
     * @param filepath
     */
    public void loadData(String filepath){
    }

    /**
     *
     * @param filepath
     * @throws IOException
     */
    public void saveTo(String filepath) throws IOException{
        if (table != null){
            try{
                FileOutputStream fileOut = new FileOutputStream(filepath);
                ObjectOutputStream out = new ObjectOutputStream(fileOut);
                out.writeObject(this.table);
                out.close();
                fileOut.close();
                System.out.println("file has been successfully saved to " + filepath);
            }
            catch(IOException ex){
                ex.printStackTrace();
                throw new IOException("Error saving the file");
            }
        }
        else{
            throw new RuntimeException("Your table is empty");
        }
    }

}
