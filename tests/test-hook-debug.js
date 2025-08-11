#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

console.log('Current directory:', process.cwd());

const files = fs.readdirSync('.');
console.log('Files found:', files);

files.forEach(file => {
    if (file.includes('.env')) {
        console.log(`\nReading ${file}...`);
        const content = fs.readFileSync(file, 'utf8');
        console.log('Content:', content);
        
        // Test pattern
        const pattern = /['\"]?[A-Z_]+['\"]?\s*[:=]\s*['\"]?[a-zA-Z0-9]{10,}['\"]?/gi;
        const matches = content.match(pattern);
        console.log('Matches:', matches);
    }
});