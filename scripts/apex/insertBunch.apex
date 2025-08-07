// Sample first and last names to randomly combine
List<String> firstNames = new List<String>{'Alex', 'Jordan', 'Taylor', 'Morgan', 'Casey', 'Drew', 'Skyler', 'Jamie', 'Riley', 'Avery', 'Sam', 'Charlie', 'Rowan'};
List<String> lastNames = new List<String>{'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Martinez', 'Taylor', 'Anderson', 'Thomas'};

// Settings
Integer totalContacts = 100;
List<Contact> contactsToInsert = new List<Contact>();

// Generate contacts
for (Integer i = 0; i < totalContacts; i++) {
    String first = firstNames[Math.mod(Math.abs(Crypto.getRandomInteger()), firstNames.size())];
    String last = lastNames[Math.mod(Math.abs(Crypto.getRandomInteger()), lastNames.size())];

    String email = first.toLowerCase() + '.' + last.toLowerCase() + i + '@example.com';

    contactsToInsert.add(new Contact(
        FirstName = first,
        LastName = last,
        Email = email,
        Phone = '555-123-' + String.valueOf(1000 + i),
        MailingCity = 'San Francisco',
        MailingState = 'CA'
    ));

    // Insert in batches of 200 to avoid limits
    if (contactsToInsert.size() == 200) {
        insert contactsToInsert;
        contactsToInsert.clear();
    }
}

// Insert any remaining
if (!contactsToInsert.isEmpty()) {
    insert contactsToInsert;
}

System.debug('Finished inserting 3000 random contacts.');
