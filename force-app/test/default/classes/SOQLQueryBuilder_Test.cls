@IsTest
private class SOQLQueryBuilder_Test {

    @IsTest
    static void queryBuilder() {
        Account parent = new Account(Name = 'Some Parent');
        insert parent;
        Account child = new Account(
                Name = 'Growteq Query Builders LLC',
                Description = 'Child account #1',
                ParentId = parent.Id,
                AccountNumber = '1234',
                AnnualRevenue = 50,
                BillingCity = 'Rotterdam'
        );
        insert child;
        Contact c = new Contact(LastName = 'Test', Email = 'test@example.com', AccountId = child.Id);
        insert c;

        Test.startTest();
        SOQLQueryBuilder query = new SOQLQueryBuilder(Account.SObjectType)
                .field(Account.Id)
                .fields(new List<SObjectField>{Account.Name, Account.Description})
                .relatedFields(Account.ParentId, new List<SObjectField>{Account.Id, Account.Name, Account.OwnerId})
                .fieldToLabel(Account.Type)
                .filter(Account.Name).isLike('%Growteq%')
                .filter(Account.ParentId).equals(parent.Id)
                .filter(Account.ParentId).notEquals(child.Id)
                .filter(Account.AccountNumber).isNotIn(new Set<String>{'1233', '1235'})
                .filter(Account.AnnualRevenue).lessThan(100)
                .filter(Account.AnnualRevenue).greaterThan(20)
                .filter(Account.CreatedDate).equalsOrLess(Date.today().addDays(1))
                .filter(Account.CreatedDate).equalsOrMore(Date.today())
                .filter(Account.OwnerId).isIn(new Set<Id>{UserInfo.getUserId()})
                .filter(Account.OwnerId).isNotIn(new List<Id>{parent.Id})
                .filter(Account.BillingCity).isNotIn(new List<String>{'Amsterdam'})
                .filterLogic('1 AND 2 AND 3 AND 4 AND (5 OR 6 AND 7) AND 8 AND 9 AND 10 AND 11')
                .orderBy(Account.Name).descending().nullsLast()
                .setLimit(10)
                .withSecurityEnforced();
        SOQLQueryBuilder contacts = query.getSubquery('Contacts')
                .field(Contact.Email)
                .field(Contact.Id)
                .whereClause('Email != null')
                .orderBy(Contact.LastName).ascending().nullsFirst();
        String errorMessage;
        try {
            query.field(null);
        } catch(SOQLQueryBuilderException e) {
            errorMessage = e.getMessage();
        }
        query.subquery(contacts);
        System.debug(query.soql());
        List<Account> results = (List<Account>) query.query();

        Test.stopTest();
        System.assertEquals(1, results.size());
        System.assertEquals(1, results[0].Contacts.size());
        System.assertEquals('Some Parent', results[0].Parent.Name);
        System.assertNotEquals(null, errorMessage);
    }
}