/**
 * @description       : 
 * @author            : tom.h.ansley@medtronic.com
 * @last modified on  : 12-10-2020
 * @last modified by  : tom.h.ansley@medtronic.com
 * Modifications Log 
 * Ver   Date         Author                       Modification
 * 1.0   12-10-2020   tom.h.ansley@medtronic.com   Initial Version
**/
public with sharing class HelperDate {
    
    /*
     * Assumes string is formatted as follows - 'MM/dd/yyyy'
     */
    public static Date getDateFromString(String theDate)
    {
        
        String[] dateValues = theDate.split('/');
        
        String month = dateValues[0];
        String dte   = dateValues[1]; 
        String year  = dateValues[2];
            
        return Date.valueOf(year + '-' + month + '-' + dte + ' 12:00:00');
            
    }

}