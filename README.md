# SOQL Query Utility

This package should help you write dynamic SOQL queries without having to revert to writing plain query strings.
Instead, you can build queries by specifying an [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_class_Schema_SObjectType.htm) and the desired [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_class_Schema_SObjectField.htm#apex_class_Schema_SObjectField)s, and also add WHERE clauses dynamically. The great advantage of this is that you reduce errors by not having to write out your full queries, and moreover, your queries will be checked at compile time. Specifying incorrect field names and only realising it when hitting a System.QueryException when running your code is history! 
Especially when using a IDE this should help you speed up getting your queries right.

## How to use

1. Create your `Query` object by supplying the correct SObjectType token to the constructor, for example `Query myQuery = new Query(Account.SObjectType);`
2. Specify the fields to select:
  * A single field: `myQuery.addField(Account.Phone);`
  * A list of fields: `myQuery.addFields(new SObjectField[]{Account.Name, Account.Email});`
  * A field on some related object: `myQuery.addField(new SObjectField[]{Account.Invoicing_Contact__c, Contact.MobilePhone});`
  * A list of related fields: `myQuery.addRelatedFields(new SObjectField[]{Account.ParentId, new SObjectField[]{Account.Email, Account.Phone});`
  * A field set name: `myQuery.addFieldSet('Account_Revenue_Fields');`
3. Add WHERE clauses, like `myQuery.addWhereClause(new SObjectField[]{Account.Name}, Operator.LIKE, 'Salesforce.%');` and `myQuery.addWhereClause(new SObjectField[]{Account.BillingCity}, Operator.EQUALS, 'San Francisco');`
4. Add a limit by calling `myQuery.setLimit(100);`
5. Get your query string by calling `myQuery.construct()` and use it in a `Database.query()` call, like `(List<Account>)Database.query(myQuery.construct());`.
