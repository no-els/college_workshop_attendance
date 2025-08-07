List<Contact> contactsToInsert = new List<Contact>();

for (Integer i = 1; i <= 20; i++) {
    contactsToInsert.add(new Contact(
        FirstName = 'TestFirst' + i,
        LastName = 'TestLast' + i,
        Email = 'test' + i + '@example.com',
        Phone = '555-000-' + String.valueOf(1000 + i),
        MailingCity = 'San Francisco',
        MailingState = 'CA'
    ));
}

insert contactsToInsert;
System.debug('Inserted ' + contactsToInsert.size() + ' contacts.');
