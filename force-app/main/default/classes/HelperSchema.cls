/**
 * @description       : 
 * @author            : tom.h.ansley@medtronic.com
 * @last modified on  : 12-10-2020
 * @last modified by  : tom.h.ansley@medtronic.com
 * Modifications Log 
 * Ver   Date         Author                       Modification
 * 1.0   12-10-2020   tom.h.ansley@medtronic.com   Initial Version
**/
public with sharing class HelperSchema {

	public static Map<String, Map<String, Schema.SObjectField>> objectDescribeFieldsByObjectName = new Map<String, Map<String, Schema.SObjectField>>();
	public static Map<String, Schema.SObjectType> objectDescribeByName = new Map<String, Schema.SObjectType>();

    public static final String KEY_LABEL = 'label';
	public static final String KEY_NAME = 'name';

    public static Schema.DisplayType getFieldType(String obj, String field)
	{
		
		Schema.DisplayType fieldType = null;
		
		Schema.SObjectField objField = getFieldByKey(obj, field, KEY_NAME);
		
		if (objField != null)
			fieldType = objField.getDescribe().getType();
		
		return fieldType;
		
	}

	public static Schema.SObjectField getFieldByKey(String obj, String key, String keyType)
	{
		
		//get the fields of the object in question
		Map<String, Schema.SObjectField> fieldsByKeyType = getFieldsForObject(obj, keyType);
		
		//get the field by key
		Schema.SObjectField field = fieldsByKeyType.get(key);

		return field;
		
	}
	
	public static Map<String, Schema.SObjectField> getFieldsForObject(String obj, String keyType)
	{
		Map<String, Schema.SObjectField> fieldsByKeyType = new Map<String, Schema.SObjectField>();
		
		//initialize if necessary
		initSObjectSchema(obj);
		
		//get the fields of the object in question
		List<Schema.SObjectField> fields = objectDescribeFieldsByObjectName.get(obj).values();
		
		//create a map of fields by name
		for (Schema.SObjectField objField: fields)
		{
			if (keyType == KEY_NAME)
				fieldsByKeyType.put(objField.getDescribe().getName(), objField);
			else if (keyType == KEY_LABEL)
				fieldsByKeyType.put(objField.getDescribe().getLabel(), objField);
		}
		
		String debug = '\n-----------------------------------------------\n';
		debug += 'OBJ      - ' + obj + '\n';
		debug += 'KEY TYPE - ' + keyType + '\n\n';
		for (String key: fieldsByKeyType.keySet())
			debug += 'KEY - ' + key + ', VALUE - ' + fieldsByKeyType.get(key) + '\n';
		debug += '-----------------------------------------------\n';

		System.debug(LoggingLevel.FINE, debug);

		return fieldsByKeyType;
		
	}

	private static void initSObjectSchema(String obj)
	{
		//if this object has not been described yet get the data
		if (objectDescribeByName.get(obj) == null)
		{
			Schema.SObjectType objSchema = Schema.getGlobalDescribe().get(obj);
			if (objSchema != null)
			{
				objectDescribeByName.put(obj, objSchema);
				objectDescribeFieldsByObjectName.put(obj, objSchema.getDescribe().fields.getMap());
			}
		}
		
    }
    
}