const fs = require('fs');
const path = require('path');

const dir = '/Users/andreasbigger/guardian/test-secrets';
const items = fs.readdirSync(dir);

console.log('All items in directory:', items);

items.forEach(item => {
    const condition1 = item.startsWith('.');
    const condition2 = item.includes('.env');
    const shouldSkip = condition1 && !condition2;
    
    console.log(`Item: ${item}`);
    console.log(`  Starts with '.': ${condition1}`);
    console.log(`  Includes '.env': ${condition2}`);
    console.log(`  Should skip: ${shouldSkip}`);
    console.log('---');
});