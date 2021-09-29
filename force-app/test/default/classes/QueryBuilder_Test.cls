@IsTest
private class QueryBuilder_Test {

    @IsTest
    static void soql() {
        QueryBuilder query = new QueryBuilder(Account.SObjectType)
                .field(Account.Id)
                .fields(new List<SObjectField>{Account.Name, Account.Description})
                .fieldToLabel(Account.Type)
                .filter(Account.Name).isLike('%SFDC%')
                .orderBy(Account.Name).descending().nullsLast()
                .setLimit(5)
                .withSecurityEnforced();
        String soql = query.soql();
        System.assertEquals('SELECT Id, Name, Description, Type ' +
                'FROM Account ' +
                'WHERE Name LIKE \'%SFDC%\' ' +
                'WITH SECURITY_ENFORCED ' +
                'ORDER BY Name DESC NULLS LAST ' +
                'LIMIT 5', soql);
    }

    @IsTest
    static void query() {
        Account acc1 = new Account(
                Name = 'SFDC Inc.',
                Description = 'Some account'
        );
        insert acc1;
        Account acc2 = new Account(
                Name = 'Apex Corp.',
                Description = 'Some other account'
        );
        insert acc2;

        Test.startTest();
        List<Account> results = (List<Account>) new QueryBuilder(Account.SObjectType)
                .field(Account.Id)
                .fields(new List<SObjectField>{Account.Name, Account.Description})
                .query();

        Test.stopTest();
        System.assertEquals(2, results.size());
    }

    @IsTest
    static void first() {
        Account acc1 = new Account(
                Name = 'SFDC Inc.',
                Description = 'Some account'
        );
        insert acc1;
        Account acc2 = new Account(
                Name = 'Apex Corp.',
                Description = 'Some other account'
        );
        insert acc2;

        Test.startTest();
        Account first = (Account) new QueryBuilder(Account.SObjectType)
                .field(Account.Id)
                .orderBy(Account.Name).descending()
                .first();

        Test.stopTest();
        System.assertEquals(first.Id, acc1.Id);
    }

    @IsTest
    static void relatedFields() {
        Account parent = new Account(Name = 'SFDC');
        insert parent;
        Account child = new Account(
                Name = 'Apex Dev Services',
                Description = 'Child account #1',
                ParentId = parent.Id
        );
        insert child;
        Contact c = new Contact(
                LastName = 'Test',
                Email = 'test@example.com',
                AccountId = child.Id
        );
        insert c;

        Test.startTest();
        QueryBuilder query = new QueryBuilder(Account.SObjectType)
                .field(Account.Id)
                .fields(new List<SObjectField>{Account.Name, Account.Description})
                .relatedFields(Account.ParentId, new List<SObjectField>{Account.Id, Account.Name, Account.OwnerId})
                .filter(Account.ParentId).notEquals(null);
        QueryBuilder contacts = query.getSubquery('Contacts')
                .field(Contact.Email)
                .field(Contact.Id)
                .whereClause('Email != null')
                .orderBy(Contact.LastName).ascending().nullsFirst();
        String errorMessage;
        try {
            query.field(null);
        } catch(QueryBuilderException e) {
            errorMessage = e.getMessage();
        }
        query.subquery(contacts);
        System.debug(query.soql());
        List<Account> results = (List<Account>) query.query();

        Test.stopTest();
        System.assertEquals(1, results.size());
        System.assertEquals(1, results[0].Contacts.size());
        System.assertEquals('SFDC', results[0].Parent.Name);
        System.assertNotEquals(null, errorMessage);
    }

    @IsTest
    static void filter() {
        Account parent = new Account(Name = 'SFDC');
        insert parent;
        Account child = new Account(
                Name = 'Query Builders LLC',
                Description = 'Child account #1',
                ParentId = parent.Id,
                AccountNumber = '1234',
                AnnualRevenue = 50,
                BillingCity = 'Rotterdam'
        );
        insert child;
        Contact contact = new Contact(
                LastName = 'Test',
                Email = 'test@example.com',
                AccountId = child.Id
        );
        insert contact;

        Test.startTest();
        QueryBuilder query = new QueryBuilder(Account.SObjectType)
                .field(Account.Id)
                .fields(new List<SObjectField>{Account.Name, Account.Description})
                .relatedFields(Account.ParentId, new List<SObjectField>{Account.Id, Account.Name, Account.OwnerId})
                .fieldToLabel(Account.Type)
                .filter(Account.Name).isLike('%Query Builder%')
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
                .filter(Account.ParentId).isIn(
                    new QueryBuilder(Account.SObjectType).field(Account.Id).filter(Account.Name).equals('SFDC'))
                .filterLogic('1 AND 2 AND 3 AND 4 AND (5 OR 6 AND 7) AND 8 AND 9 AND 10 AND 11');
        List<Account> results = (List<Account>) query.query();

        Test.stopTest();
        System.assertEquals(1, results.size());
        System.assertEquals('SFDC', results[0].Parent.Name);
    }

    @IsTest
    static void filter_multipicklist() {
        QuickText qt = new QuickText(
                Name = 'Test',
                Message = 'Hi!',
                Channel = 'Email;Portal;Task'
        );
        insert qt;

        Test.startTest();
        QuickText result = (QuickText) new QueryBuilder(QuickText.SObjectType)
                .field(QuickText.Id)
                .field(QuickText.Message)
                .filter(QuickText.Channel).includes('Email')
                .filter(QuickText.Channel).includes(new Set<String>{'Portal', 'Task'})
                .filter(QuickText.Channel).excludes('Internal')
                .filter(QuickText.Channel).excludes(new Set<String>{'Event', 'Phone'})
                .first();

        Test.stopTest();
        System.assertEquals(qt.Id, result.Id);
    }

    @IsTest
    static void fieldSet() {
        // TODO: mock field sets and properly test related object field sets
        FieldSet fs = getSomeFieldSet();

        Test.startTest();
        String soql;
        String errorMessage;
        if(fs == null) {
            try {
                soql = new QueryBuilder(Account.SObjectType)
                        .fieldSet('NonExistingFieldSet')
                        .soql();
            } catch (Exception e) {
                errorMessage = e.getMessage();
            }
        } else {
            soql = new QueryBuilder(fs.SObjectType)
                    .fieldSet(fs)
                    .soql();
        }

        Test.stopTest();
        System.assert(fs == null ? String.isNotBlank(errorMessage) : errorMessage == null);
        System.assert(fs == null ? soql == null : String.isNotBlank(soql));
    }

    static FieldSet getSomeFieldSet() {
        for(SObjectType sObjectType : Schema.getGlobalDescribe().values()) {
            for(FieldSet fs : sObjectType.getDescribe().fieldSets.getMap().values()) {
                return fs;
            }
        }
        return null;
    }
}